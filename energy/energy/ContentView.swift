//
//  ContentView.swift
//  energy
//
//  Created by Dirk Clemens on 12.03.23.
//

import Foundation
import SwiftUI
import CocoaMQTT
import SwiftyJSON // https://github.com/SwiftyJSON/SwiftyJSON
import Charts

var mqtt: CocoaMQTT?

struct ContentView: View {
    
    //evcc/site/homePower                   --> Verbrauch
    //evcc/site/gridPower                   --> Netzbezug
    //evcc/site/pv/1/power                  --> Erzeugung
    //evcc/site/pvPower                     --> Erzeugung
    //evcc/loadpoints/1/chargePower         --> Ladepunkt
    //smarthome/tele/tasmota7163/SENSOR     --> SML
    //energy/growatt/modbusdata/outputpower --> Erzeugung
    //energy/growatt/modbusdata/energytoday --> Erzeugung heute
    //energy/growatt/modbusdata/energytotal --> Erzeugung gesamt
    
    @State var mqttStateLabel = "NOT connected tp MQTT server"
    @State var mqttHomePowerLabel = "0 W"
    @State var mqttGridInPowerLabel = "0 W"
    @State var mqttGridOutPowerLabel = "0 W"
    @State var mqttPowerLabel = "0 W"
    @State var mqttChargePowerLabel = "0 W"
    @State var mqttOutputPowerLabel = "0 W"
    @State var mqttEnergyTodayLabel = "0.0 kW"
    @State var mqttEnergyTotalLabel = "0.0 kW"
    @State var mqttSMLLabel = "- kWh\n- kWh\n- Wh"
    @State var mqttVehicleLabel = ""
    @State var mqttVehicleRange = "km" // Reichweite
    @State var mqttVehicleSoc = "%" // Ladung %
    @State var mqttVehicleOdometer = "km" // Laufleistung

    @State private var connectToServer = false

    @State var mqttHomePower = 0.0
    @State var mqttGridPower = 0.0
    @State var mqttGridInPower = 0.0
    @State var mqttGridOutPower = 0.0
    @State var mqttPower = 0.0
    @State var mqttChargePower = 0.0

    @State var isConnected: Bool = false {
        didSet {
//                isConnected = self.mqtt.connect()

//                if isConnected != station.isDisplayed {
//                    PWSStore.shared.toggleIsDisplayed(station)
//                }
        }
    }
    
    let clientID = "CocoaMQTT-" + String(ProcessInfo().processIdentifier)
    let mqtt = CocoaMQTT(clientID: "CocoaMQTT-clientID", host: "192.168.2.222", port: 1883)
    //let mqtt = CocoaMQTT(clientID: "CocoaMQTT-clientID", host: "broker-cn.emqx.io", port: 1883)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var gridPowerColor: Color {
//        let value = (mqttGridPowerLabel as NSString).integerValue
        return mqttGridPower < 0 ? .green : .red
    }
    
    func string2Int(str: String) -> Int {
        let value = (str as NSString).integerValue
        return value
    }
    
    @State private var showLegend = true
    
    struct EnergyBalance{
        var id: String { source }
        var source: String
        var val: Int
    }
    @State var data0: [EnergyBalance] = [
        .init(source: "Erzeugung", val: 0),
        .init(source: "Netzbezug", val: 0),
        .init(source: "Verbrauch", val: 0),
        .init(source: "Einspeisung", val: 0)
    ]

    let steelBlue = Color(red: 0.20, green: 0.47, blue: 0.97)
    let lemonYellow = Color(hue: 0.1639, saturation: 1, brightness: 1)
    let steelGray = Color(white: 0.4745)
    let evccGreen = Color(red:0.152, green:0.8, blue:0.255)
    let evccOrange = Color(red:0.998, green:0.584, blue:0)

    @State private var isCharging = false
    
    var body: some View {

        VStack(alignment: .leading) {
            HStack {
                Text("Energiebilanz")
//                Image(systemName: "sun.max.fill")
//                    .foregroundStyle(lemonYellow)
                Spacer()
                Text("aktuell")
                    .foregroundColor(.secondary)
            }
            Divider().frame(height: 2)
            HStack {
                Text("IN")
                    .foregroundColor(.secondary).bold()
                Spacer()
                Text("OUT")
                    .foregroundColor(.secondary).bold()
            }
            Chart(data0, id: \.source) { element in
                BarMark(
                    x: .value("Energiebilanz", element.val)
                )
                .foregroundStyle(by: .value("Watt", element.source))
                .annotation(position: .overlay, alignment: .center) {
                    Text("\(element.val) W")
                        .font(.caption)
                }
//                .clipShape(Capsule())
                .foregroundStyle(Color.clear)
                .cornerRadius(5)
            } // Chart
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(2)
            }
            .chartLegend(position: .bottom, alignment: .center)
            .chartForegroundStyleScale([
                "Netzbezug" : steelGray,
                "Erzeugung": evccGreen,
                "Verbrauch" : evccOrange,
                "Einspeisung": lemonYellow]
            )
//            .chartLegend(showLegend ? .visible : .hidden)
//            .chartLegend(.visible)
//            .chartXAxis(.hidden)
//            .chartYAxis(.hidden)
            .frame(height: 60)
        } // VStack
        .padding()
//        .padding(.leading, 15)
//        .padding(.trailing, 15)
//        .frame(width: 450, height: 80)
        .frame(minWidth: 350, minHeight: 140)
//        .fixedSize()
        
        VStack (spacing: 0) {
            Group {
                Section(){
                    HStack(alignment: .center, spacing: 0) {
                        Text("IN").bold()
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttPower + mqttGridInPower)).bold()
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Erzeugung:")
                        Spacer()
                        Text(mqttOutputPowerLabel)
                            .foregroundColor(.secondary.opacity(0.2))
                        Spacer().frame(width: 10)
                        Text(String(format: "%\(0.01)f W", mqttPower))
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Netzbezug:")
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttGridInPower))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } // Group
                
            Divider().frame(height: 10)

            Group {
                Section(){
                    HStack(alignment: .center, spacing: 0) {
                        Text("OUT").bold()
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttHomePower + mqttChargePower + (mqttGridOutPower * (-1)))).bold()
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Verbrauch:")
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttHomePower))
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Ladepunkt:")
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttChargePower))
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Einspeisung:")
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttGridOutPower))
//                            .foregroundColor(gridPowerColor)
                    }
                } // Section
                .frame(maxWidth: .infinity, alignment: .leading)
            } // Group
            
            Divider().frame(height: 10)
            
            Group {
                Section(header: Text("PV").bold()){
                    HStack(alignment: .center, spacing: 0) {
                        Text("heute / gesamt: ")
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(lemonYellow)
                        Spacer()
                        Text(mqttEnergyTodayLabel)
                        Spacer().frame(width: 10)
                        Text(mqttEnergyTotalLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } // Section
                .frame(maxWidth: .infinity, alignment: .leading)
            } // Group

            Divider().frame(height: 10)
                    
            Group {
                HStack(alignment: .top, spacing: 0) {
                    Section(header: Text("SML").bold()){
                        HStack(alignment: .bottom, spacing: 0) {
                            Spacer()
                            Text(mqttSMLLabel)
                                .multilineTextAlignment(.trailing)
                                .frame(minHeight: 60)
                        }
                    } // Section
                    
                    
                    if (self.isCharging){
                        Spacer().frame(width: 30)

                        Section(header: Text("Auto").bold()){
                            HStack(alignment: .bottom, spacing: 0) {
                                Spacer()
                                VStack(){
                                    Text(mqttVehicleRange + "\n" + mqttVehicleSoc + "\n" + mqttVehicleOdometer)
                                        .multilineTextAlignment(.trailing)
                                        .frame(minHeight: 60)
                                }
                            }
                        } // Section
                    }
                }
            } // Group
            
            Divider().frame(height: 10)
            
            ///
            /// XCode->Targets->Capabilities check [outgoing connections] on
            /// https://github.com/emqx/CocoaMQTT/issues/444#issuecomment-1072787295
            ///
            Group {
                HStack(alignment: .center, spacing: 0) {
                    Text("Status: ")
                    Spacer()
                    Text(mqttStateLabel)
                        .foregroundColor(.secondary)
//                        .bold(self.mqtt.connState == .connected ? false : true)
                        .onReceive(timer) { _ in
                            self.mqtt.didConnectAck = { mqtt, ack in
                                //self.mqtt.subscribe("#")
                                self.mqtt.subscribe("evcc/site/#")
                                self.mqtt.subscribe("evcc/loadpoints/1/#")
                                self.mqtt.subscribe("smarthome/tele/tasmota7163/#")
                                self.mqtt.subscribe("energy/growatt/modbusdata/#")
                                self.mqtt.didReceiveMessage = { mqtt, message, id in
                                    
                                    print("[topic] : \(message.topic)")
                                    
                                    if (message.topic.contains("evcc/site/homePower")) {
                                        if (message.string != nil){
                                            self.mqttHomePowerLabel = ("\(message.string!) W")
                                            self.mqttHomePower = Double(String(message.string!))!
                                        }
                                    }
                                    
                                    if (message.topic.contains("evcc/site/gridPower")) {
                                        if (message.string != nil){
                                            self.mqttGridPower = Double(String(message.string!))!
//                                            let gridPower = string2Int(str: message.string!)
                                            if self.mqttGridPower < 0 {
                                                self.mqttGridInPowerLabel = ("0 W")
                                                self.mqttGridInPower = 0.0
                                                self.mqttGridOutPowerLabel = ("\(message.string!) W")
                                                self.mqttGridOutPower = Double(String(message.string!))!
                                            }
                                            else{
                                                self.mqttGridInPowerLabel = ("\(message.string!) W")
                                                self.mqttGridInPower = Double(String(message.string!))!
                                                self.mqttGridOutPowerLabel = ("0 W")
                                                self.mqttGridOutPower = 0.0
                                            }
                                        }
                                    }
                                    
                                    if (message.topic.contains("evcc/loadpoints/1/chargePower")) {
                                        if (message.string != nil){
                                            self.mqttChargePowerLabel = ("\(message.string!) W")
                                            self.mqttChargePower = Double(String(message.string!))!
                                        }
                                    }
                                    
                                    if (message.topic.contains("evcc/loadpoints/1/charging")) {
                                        if ((message.string?.contains("true")) != nil){
                                            self.isCharging = true
                                        } else {
                                            self.isCharging = false
                                        }
                                    }
                                    if (message.topic.contains("evcc/loadpoints/1/vehicleRange")) {
                                        if (message.string != nil){
                                            self.mqttVehicleRange = ("\(message.string!) km")
                                        }
                                    }
                                    if (message.topic.contains("evcc/loadpoints/1/vehicleSoc")) {
                                        if (message.string != nil){
                                            self.mqttVehicleSoc = ("\(message.string!) %")
                                        }
                                    }
                                    if (message.topic.contains("evcc/loadpoints/1/vehicleOdometer")) {
                                        if (message.string != nil){
                                            self.mqttVehicleOdometer = ("\(message.string!) km")
                                        }
                                    }

                                    if (message.topic.contains("energy/growatt/modbusdata")) {
                                        if (message.string != nil){
                                            let payload = String(message.string!)
                                            if let dataFromString = payload.data(using: .utf8, allowLossyConversion: false) {
                                                let json = try? JSON(data: dataFromString)
                                                self.mqttOutputPowerLabel = ("(\(json?["outputpower"].stringValue ?? "") W)")
                                                self.mqttEnergyTodayLabel = ("\(json?["energytoday"].stringValue ?? "") kW")
                                                self.mqttEnergyTotalLabel = ("\(json?["energytotal"].stringValue ?? "") kW")
                                            }
                                        }
                                    }
                                    
                                    if (message.topic.contains("evcc/site/pv/1/power")) {
                                        if (message.string != nil){
                                            self.mqttPowerLabel = ("\(message.string!) W")
                                            self.mqttPower = Double(String(message.string!))!
                                        }
                                    }
                                    
                                    if (message.topic.contains("smarthome/tele/tasmota7163/SENSOR")) {
                                        if (message.string != nil){
                                            let payload = String(message.string!)
                                            if let dataFromString = payload.data(using: .utf8, allowLossyConversion: false) {
                                                let json = try? JSON(data: dataFromString)
                                                let str = ("\(json?["SML"]["Total_in"].stringValue ?? "") kWh \n\(json?["SML"]["Total_out"].stringValue ?? "") kWh \n\(json?["SML"]["Power_curr"].stringValue ?? "") Wh")
                                                self.mqttSMLLabel = str
                                            }
                                        }
                                    }
                                    
                                    data0.removeAll()
                                    var netzbezug = 0.0
                                    var einspeisung = 0.0
                                    let verbrauch = mqttHomePower * (-1)
                                    if (mqttGridPower >= 0){
                                        netzbezug = mqttGridPower
                                    } else {
                                        einspeisung = mqttGridPower * (-1)
                                    }
                                    let erzeugung = mqttPower * 1.0
                                    
                                    data0.append(EnergyBalance(source: "Erzeugung", val: Int(erzeugung)))
                                    data0.append(EnergyBalance(source: "Netzbezug", val: Int(netzbezug)))
                                    data0.append(EnergyBalance(source: "Verbrauch", val: Int(verbrauch)))
                                    data0.append(EnergyBalance(source: "Einspeisung", val: Int(einspeisung)))
                                    
                                }
                            }
                            //self.mqtt.logLevel = .debug
                            self.mqtt.username = "***"
                            self.mqtt.password = "***"
                            /// https://github.com/emqx/CocoaMQTT/issues/502
                            self.mqtt.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
                            self.mqtt.keepAlive = 60
                            self.mqtt.enableSSL = false
                            
                            if (self.mqtt.connState == .connected) {
                                //print("connected")
                                isConnected = false
                                self.mqttStateLabel = ("connected to MQTT server")
                            } else {
                                //print("disconnected")
                                self.mqttStateLabel = ("NOT connected to MQTT server")
                                isConnected = self.mqtt.connect()
                            }
                        }
                } // HStack
            } // Group

        } // VStack
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.gray, lineWidth: 0.2)
        )
        .padding(.leading, 15)
        .padding(.trailing, 15)
//        .frame(width: 450, height: 330)
        .frame(minWidth: 400, minHeight: 315)
//        .fixedSize()
//        .scaledToFit()

        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

