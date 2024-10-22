// bomberfish
// VMManager.swift – FishVM
// created on 2024-10-19

import SwiftUI
import Virtualization
import OSLog
import DefaultCodable

fileprivate let logger = Logger(subsystem: "FishVM", category: "VMManager")

class VMManager: NSObject, ObservableObject, VZVirtualMachineDelegate {
    
    static let shared = VMManager()
    
    @Published var vms: [VirtualMachine] = []
    @Published var currentlyRunningVM: VirtualMachine?
    @Published var currentlyRunningVZVM: VZVirtualMachine?
    
    @Published var startInProgress = false
    @Published var stopInProgress = false
    
    /// Value does not matter. Observe for change.
    @Published var windowCloseEvent = false
    
    
    override init() {
        super.init()
        do {
            try enumerateVMs()
        } catch {
            logger.fault("\(error)")
        }
    }
    
    func createVM(config: VMConfig, diskSize: Int) throws {
        logger.debug("Creating VM")
        let bundle = vmURL.appendingPathComponent(config.name + ".bundle")
        let vm = VirtualMachine(path: bundle, config: config)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        
        try vm.saveConfig()
        
        logger.debug("Creating EFI Variable Store")
        let _ = try VZEFIVariableStore(creatingVariableStoreAt: vm.efiVarPath)
        
        logger.debug("Creating blank image")
        try Data().write(to: vm.diskImagePath)

        logger.debug("Filling disk")
        let mainDiskFileHandle = try FileHandle(forWritingTo: vm.diskImagePath)
        try mainDiskFileHandle.truncate(atOffset: UInt64(diskSize * 1024 * 1024 * 1024))
        
        logger.debug("Done!")
        vms.append(.init(path: bundle, config: config))
    }
    
    func deleteVM(_ vm: VirtualMachine) throws {
        try FileManager.default.removeItem(at: vm.path)
        vms.removeAll(where: {$0 == vm})
    }
    
    /// Makes a `VZVirtualMachineConfiguration` from a `VirtualMachine`
    func getAppleyConfigFromOurVM(_ vm: VirtualMachine) throws -> VZVirtualMachineConfiguration {
        let cfg = VZVirtualMachineConfiguration()
        
        // MARK: CPU
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount
        
        var cpu = vm.config.cpuCores
        cpu = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
        cpu = max(cpu, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        cpu = min(cpu, VZVirtualMachineConfiguration.maximumAllowedCPUCount)
        if cpu != vm.config.cpuCores {
            logger.warning("Configured cpu core count \(vm.config.cpuCores) outside host allowed bounds, set to \(cpu)")
        }
        
        cfg.cpuCount = cpu
        
        // MARK: RAM
        var ram = UInt64(vm.config.ramAmount*1024*1024)
        ram = max(ram, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        ram = min(ram, VZVirtualMachineConfiguration.maximumAllowedMemorySize)
        
        if ram != UInt64(vm.config.ramAmount*1024*1024) {
            logger.warning("Configured RAM allocation \(vm.config.ramAmount) MiB outside host allowed allocation bounds, set to \(ram)")
        }
        
        cfg.memorySize = ram
        
        let plat = VZGenericPlatformConfiguration()
        let bl = VZEFIBootLoader()
        var disks: [VZStorageDeviceConfiguration] = []
        
        // MARK: Platform and Bootloader
        plat.machineIdentifier = vm.config.id.value
        logger.debug("ID: \(vm.config.id.value.dataRepresentation)")
        bl.variableStore = VZEFIVariableStore(url: vm.efiVarPath)
        
        
        cfg.platform = plat
        cfg.bootLoader = bl
        
        // MARK: Storage
        if let usb = vm.config.attachedUSBImagePath {
           let usbAttachment = try VZDiskImageStorageDeviceAttachment(url: usb, readOnly: true)
            disks.append(VZUSBMassStorageDeviceConfiguration(attachment: usbAttachment))
        }
        
        let mainDiskAttachment = try VZDiskImageStorageDeviceAttachment(url: vm.diskImagePath, readOnly: false)
        disks.append(VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment))
        
        cfg.storageDevices = disks
        
        // MARK: Networking
        let net = VZVirtioNetworkDeviceConfiguration()
        net.attachment = VZNATNetworkDeviceAttachment()
        cfg.networkDevices = [net]
        
        // MARK: Graphics
        let gfx = VZVirtioGraphicsDeviceConfiguration()
        logger.debug("FB is \(vm.config.fbWidth)x\(vm.config.fbHeight)")
        gfx.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: vm.config.fbWidth, heightInPixels: vm.config.fbHeight)
        ]
        cfg.graphicsDevices = [gfx]
        
        // MARK: Audio
        
        // Out
        let aout = VZVirtioSoundDeviceConfiguration()
        let outstr = VZVirtioSoundDeviceOutputStreamConfiguration()
        outstr.sink = VZHostAudioOutputStreamSink()
        aout.streams = [outstr]
        
        // In
        let ain = VZVirtioSoundDeviceConfiguration()
        let instr = VZVirtioSoundDeviceInputStreamConfiguration()
        instr.source = VZHostAudioInputStreamSource()
        ain.streams = [instr]
        cfg.audioDevices = [aout, ain]
        
        // MARK: Input
        cfg.keyboards = [VZUSBKeyboardConfiguration()]
        cfg.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        
        // MARK: SPICE
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()
        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort
        cfg.consoleDevices = [consoleDevice]
        
        
        cfg.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        
        try cfg.validate()
        
        return cfg
    }
    
    func startVM(_ vm: VirtualMachine) throws {
        startInProgress = true
        defer { startInProgress = false }
        let cfg = try self.getAppleyConfigFromOurVM(vm)
        currentlyRunningVZVM = VZVirtualMachine(configuration: cfg)
        
        guard currentlyRunningVZVM != nil else {
            throw "VZVirtualMachine creation failed for an unknown reason"
        }

        currentlyRunningVZVM!.delegate = self
        currentlyRunningVM = vm

        currentlyRunningVZVM!.start { result in
            switch result {
            case .success:
                print("VM started successfully.")
            case .failure(let error):
                print("Failed to start VM: \(error.localizedDescription)")
                self.currentlyRunningVM = nil
                self.currentlyRunningVZVM = nil
            }
        }
    }

    
    func stopRunningVM() throws {
        stopInProgress = true
        defer { stopInProgress = false }
        if let vm = currentlyRunningVZVM {
            guard vm.canStop else { throw "Can't stop the VM at this time." }
            
            if vm.canRequestStop {
                try vm.requestStop()
            } else {
                Task {
                    try await vm.stop()
                }
            }
        } else {
            logger.fault("stopRunningVM() called without a running VM")
            throw "There is no running VM."
        }
    }
    
    func removeVM(_ vm: VirtualMachine) throws {
        try FileManager.default.removeItem(atPath: vm.path.path())
        vms.removeAll(where: {$0 == vm})
    }
    
    func enumerateVMs() throws {
        let files = try FileManager.default.contentsOfDirectory(at: vmURL, includingPropertiesForKeys: nil)
        
        for file in files {
            if file.hasDirectoryPath && file.isFileURL && file.pathExtension == "bundle" {
                let decoder = PropertyListDecoder()
                let plistURL = file.appendingPathComponent("config.plist")
                do {
                    let data = try Data(contentsOf: plistURL)
                    let config = try decoder.decode(VMConfig.self, from: data)
                    logger.debug("Successfully enumerated VM at path \(file.path())")
                    vms.append(.init(path: file, config: config))
                } catch {
                    logger.fault("Error getting config: \(error)")
                }
            } else {
                logger.warning("File \(file.path()) isn't meant to be here!")
            }
        }

    }
    
    func renameVM() throws {
        throw "Not implemented"
    }
    
    private func GetVZError(_ error: Error) -> String {
        switch VZError.Code(rawValue: (error as NSError).code).unsafelyUnwrapped {
        case .internalError:
            return "Internal Error"
        default:
           return "Unknown error"
        }
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        logger.critical("Virtual machine did stop with error: \(error). VZError: \(self.GetVZError(error))")
        currentlyRunningVM = nil
        currentlyRunningVZVM = nil
        if UserDefaults.standard.bool(forKey: "CloseWindowOnShutdown") { windowCloseEvent.toggle() }
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("Guest did stop virtual machine.")
        currentlyRunningVM = nil
        currentlyRunningVZVM = nil
        if UserDefaults.standard.bool(forKey: "CloseWindowOnShutdown") { windowCloseEvent.toggle() }
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
        logger.warning("Network attachment was disconnected with error: \(error)")
    }
}

/// `VZGenericMachineIdentifier`, but better
struct VZBetterGenericMachineIdentifier: Codable, Equatable, Hashable {
    static func == (lhs: VZBetterGenericMachineIdentifier, rhs: VZBetterGenericMachineIdentifier) -> Bool {
        return lhs.value.dataRepresentation == rhs.value.dataRepresentation
    }
    
    let value: VZGenericMachineIdentifier
    
    init(value: VZGenericMachineIdentifier) {
        self.value = value
    }
    
    init() {
        self.value = .init()
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.value.dataRepresentation, forKey: .id)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Data.self, forKey: .id)
        self.init(value: .init(dataRepresentation: id)!)
    }
    
}

struct VirtualMachine: Identifiable, Equatable, Hashable {
    
    let id: VZGenericMachineIdentifier
    let path: URL
    var config: VMConfig
    
    var diskImagePath: URL {
        return path.appendingPathComponent("Disk.img")
    }
    
    var efiVarPath: URL {
        return path.appendingPathComponent("NVRAM.bin")
    }
    
    init(path: URL, config: VMConfig) {
        self.id = config.id.value
        self.path = path
        self.config = config
    }
    
    
    func saveConfig() throws {
        logger.debug("Saving config...")
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(config)
        let plistURL = path.appendingPathComponent("config.plist")
        try data.write(to: plistURL)
        logger.info("Saved config!")
    }
}

enum IconType: String, Codable {
    case system = "SystemImage"
    case assetCatalog = "AssetCatalog"
}

extension Icon: DefaultValueProvider {
    static let `default` = Icon(type: .system, name: "pc")
}

struct Icon: Identifiable, Codable, Equatable, Hashable {
    var id: String
    
    var type: IconType
    var name: String
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case name = "Name"
    }
    
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(IconType.self, forKey: .type)
        name = try values.decode(String.self, forKey: .name)
        id = "\(type.rawValue).\(name)"
    }
    
    init(type: IconType, name: String) {
        self.id = "\(type.rawValue).\(name)"
        self.type = type
        self.name = name
    }
}

struct VMConfig: Identifiable, Codable, Equatable, Hashable {
    let id: VZBetterGenericMachineIdentifier
    
    /// The name of the VM.
    var name: String
    
    /// The icon
    @Default<Icon>
    var icon: Icon
    
    /// Where the image to attach is located
    var attachedUSBImagePath: URL?
    
    /// The amount of CPU cores the VM can use
    var cpuCores: Int
    
    /// The amount of allocated RAM, in MB
    var ramAmount: Int
    
    /// Width of the framebuffer
    var fbWidth: Int
    
    /// Height of the framebuffer
    var fbHeight: Int
    
    init(id: VZBetterGenericMachineIdentifier = .init(), name: String, icon: Icon = .init(type: .system, name: "desktopcomputer"), attachedUSBImagePath: URL?, cpuCores: Int, ramAmount: Int, fbWidth: Int = 1280, fbHeight: Int = 720) {
        self.id = VZBetterGenericMachineIdentifier()
        self.name = name
        self.icon = icon
        self.attachedUSBImagePath = attachedUSBImagePath
        self.cpuCores = cpuCores
        self.ramAmount = ramAmount
        self.fbWidth = fbWidth
        self.fbHeight = fbHeight
    }
}
