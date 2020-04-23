//
//  PeripheralManager.swift
//  nRF Toolbox
//
//  Created by Nick Kibysh on 04/09/2019.
//  Copyright © 2019 Nordic Semiconductor. All rights reserved.
//

import Foundation
import CoreBluetooth

enum PeripheralStatus: CustomDebugStringConvertible, Equatable {
    
    case poweredOff
    case connecting
    case connected(CBPeripheral)
    case disconnected(Error?)
    case discoveringServicesAndCharacteristics
    case discoveredRequiredServicesAndCharacteristics

    static func ==(lhs: PeripheralStatus, rhs: PeripheralStatus) -> Bool {
        switch (lhs, rhs) {
        case (.poweredOff, poweredOff): return true
        case (.connecting, .connecting): return true
        case (.connected(let p1), .connected(let p2)): return p1 == p2
        case (.disconnected, .disconnected): return true
        case (.discoveringServicesAndCharacteristics, .discoveringServicesAndCharacteristics): return true
        case (.discoveredRequiredServicesAndCharacteristics, .discoveredRequiredServicesAndCharacteristics): return true
        default: return false
        }
    }

    var debugDescription: String {
        switch self {
        case .connecting: return "connecting"
        case .connected(let p): return "connected to \(p.name ?? "__unnamed__")"
        case .disconnected: return "disconnected"
        case .poweredOff: return "powered off"
        case .discoveringServicesAndCharacteristics: return "discovering services"
        case .discoveredRequiredServicesAndCharacteristics: return "discovered required services"
        }
    }
}

protocol StatusDelegate {
    func statusDidChanged(_ status: PeripheralStatus)
}

protocol PeripheralListDelegate {
    func peripheralsFound(_ peripherals: [DiscoveredPeripheral])
}

protocol PeripheralConnectionDelegate {
    func scan(peripheral: PeripheralDescription)
    func connect(peripheral: DiscoveredPeripheral)
    func closeConnection(peripheral: CBPeripheral)
}

class PeripheralManager: NSObject {
    
    private let manager: CBCentralManager
    private var peripherals: Set<CBPeripheral> = []
    private var timer: Timer?
    
    var delegate: StatusDelegate?
    var peripheralListDelegate: PeripheralListDelegate?
    var connectingPeripheral: CBPeripheral?
    var status: PeripheralStatus = .disconnected(nil) {
        didSet {
            self.delegate?.statusDidChanged(status)
        }
    }
    
    init(peripheral: PeripheralDescription, manager: CBCentralManager = CBCentralManager()) {
        self.manager = manager
        super.init()
        self.manager.delegate = self
    }
    
    func connect(peripheral: Peripheral) {
        let uuid = peripheral.peripheral.identifier
        guard let p = manager.retrievePeripherals(withIdentifiers: [uuid]).first else {
            return
        }
        connectingPeripheral = p 
        manager.connect(p, options: nil)

        self.status = .connecting
        
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { [weak self] (_) in
            self?.closeConnection(peripheral: p)
            self?.status = .disconnected(QuickError(message: "Connection timeout"))
        })
    }
}

extension PeripheralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            self.status = .poweredOff
        case .poweredOn:
            self.status = .disconnected(nil)
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        SystemLog(category: .ble, type: .debug).log(message: "Discovered peripheral: \(advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "__unnamed__")")
        peripherals.insert(peripheral)
        peripheralListDelegate?.peripheralsFound(peripherals.map { DiscoveredPeripheral(with: $0, RSSI: RSSI.int32Value) } )
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        SystemLog(category: .ble, type: .debug).log(message: "Connected to device: \(peripheral.name ?? "__unnamed__")")
        status = .connected(peripheral)
        timer?.invalidate()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        SystemLog(category: .ble, type: .error).log(message: error?.localizedDescription ?? "Failed to Connect: (no message)")
        timer?.invalidate()
        status = .disconnected(QuickError(message: "Unable to connect"))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        SystemLog(category: .ble, type: .debug).log(message: "Disconnected peripheral: \(peripheral)")
        error.map { SystemLog(category: .ble, type: .error).log(message: "Disconnected peripheral with error: \($0.localizedDescription)") }
        status = .disconnected(error)
        timer?.invalidate()
    }
}

extension PeripheralManager: PeripheralConnectionDelegate {
    func scan(peripheral: PeripheralDescription) {
        manager.scanForPeripherals(withServices: peripheral.uuid.flatMap { [$0] }, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
    }
    
    func closeConnection(peripheral: CBPeripheral) {
        manager.cancelPeripheralConnection(peripheral)
    }
    
    func connect(peripheral: DiscoveredPeripheral) {
        manager.connect(peripheral.peripheral, options: nil)
        manager.stopScan()
    }
}
