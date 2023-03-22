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

/// https://stackoverflow.com/questions/56496359/swiftui-view-viewdidload
struct ViewDidLoadModifier: ViewModifier {
    @State private var didLoad = false
    private let action: (() -> Void)?
    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }
    func body(content: Content) -> some View {
        content.onAppear {
            if didLoad == false {
                didLoad = true
                action?()
            }
        }
    }
}
extension View {
    func onLoad(perform action: (() -> Void)? = nil) -> some View {
        modifier(ViewDidLoadModifier(perform: action))
    }
}


struct ContentView: View {

    struct EnergyBalance{
        var id: String { source }
        var source: String
        var val: Int
    }
    @State var data0: [EnergyBalance] = [
        .init(source: "Netzbezug", val: 0),
        .init(source: "Erzeugung", val: 0),
        .init(source: "Einspeisung", val: 0),
        .init(source: "Verbrauch", val: 0)
    ]

    let steelBlue = Color(red: 0.20, green: 0.47, blue: 0.97)
    let lemonYellow = Color(hue: 0.1639, saturation: 1, brightness: 1)
    let steelGray = Color(white: 0.4745)
    let evccGreen = Color(red:0.152, green:0.8, blue:0.255)
    let evccOrange = Color(red:0.998, green:0.584, blue:0)
    
    @State var mqttStateLabel = "NOT connected tp MQTT server"
    @State var mqttHomePowerLabel = "0 W"           //evcc/site/homePower                   --> Verbrauch
    @State var mqttGridInPowerLabel = "0 W"         //evcc/site/gridPower                   --> Netzbezug
    @State var mqttGridOutPowerLabel = "0 W"        //evcc/site/gridPower                   --> Netzbezug
    @State var mqttPowerLabel = "0 W"               //evcc/site/pv/1/power                  --> Erzeugung
                                                    //evcc/site/pvPower                     --> Erzeugung
    @State var mqttChargePowerLabel = "0 W"         //evcc/loadpoints/1/chargePower         --> Ladepunkt
    @State var mqttOutputPowerLabel = "0 W"         //energy/growatt/modbusdata/outputpower --> Erzeugung
    @State var mqttEnergyTodayLabel = "0.0 kW"      //energy/growatt/modbusdata/energytoday --> Erzeugung heute
    @State var mqttEnergyTotalLabel = "0.0 kW"      //energy/growatt/modbusdata/energytotal --> Erzeugung gesamt
    @State var mqttSMLLabel = "- kWh\n- kWh\n- Wh"  //smarthome/tele/tasmota7163/SENSOR     --> SML
                                                    
                                                    //evcc/loadpoints/1/charging
    @State var mqttVehicleRange = "km"              //evcc/loadpoints/1/vehicleRange        --> Reichweite
    @State var mqttVehicleSoc = " "                 //evcc/loadpoints/1/vehicleSoc          --> Ladung %
    @State var mqttVehicleOdometer = "km"           //evcc/loadpoints/1/vehicleOdometer     --> Laufleistung
        
    @State var mqttHomePower = 0.0
    @State var mqttGridPower = 0.0
    @State var mqttGridInPower = 0.0
    @State var mqttGridOutPower = 0.0
    @State var mqttPower = 0.0
    @State var mqttChargePower = 0.0
    
    let clientID = "CocoaMQTT-" + String(ProcessInfo().processIdentifier)
    let mqtt = CocoaMQTT(clientID: "CocoaMQTT-clientID", host: "192.168.2.222", port: 1883)
    //let mqtt = CocoaMQTT(clientID: "CocoaMQTT-clientID", host: "broker-cn.emqx.io", port: 1883)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State var isCharging = false // toggle visibility of "Auto"
    @State var isConnected: Bool = false // initially not connected
    @State var doConnect: Bool = true

    var body: some View {

        VStack(alignment: .leading) {
            HStack {
                Text("Energiebilanz")
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
                    Text("\(element.val) W").font(.caption)
                }
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
                "Netzbezug" : steelBlue,
                "Erzeugung": .orange,
                "Einspeisung": lemonYellow,
                "Verbrauch" : evccGreen]
            )
//            .chartLegend(showLegend ? .visible : .hidden)
//            .chartLegend(.visible)
//            .chartXAxis(.hidden)
//            .chartYAxis(.hidden)
            .frame(height: 60)
        } // VStack
        .onLoad {
            print("View().onLoad")
            mqttSettings()
        }
        .onAppear {
            print("View().onAppear -> isConnected: \(isConnected)")
//            isConnected = self.mqtt.connect()
        }
        .onDisappear {
            print("View().onDisappear")
            self.mqtt.disconnect()
        }
        .padding()
        .frame(minWidth: 350, minHeight: 140)

        VStack (spacing: 0) {
            Group {
                Section(){
                    HStack(alignment: .center, spacing: 0) {
                        Text("IN").bold()
                        Spacer()
                        Text(String(format: "%\(0.01)f W", mqttPower + mqttGridInPower)).bold()
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Erzeugung (PV):")
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
                    }
                } // Section
                .frame(maxWidth: .infinity, alignment: .leading)
            } // Group
            
            Divider().frame(height: 10)
            
            Group {
                Section(header: Text("PV").bold()){
                    HStack(alignment: .center, spacing: 0) {
                        Text("heute / gesamt: ")
//                        Image(systemName: "sun.max.fill")
//                            .foregroundStyle(lemonYellow)
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
//                        .onHover { _ in
//                            isCharging = !isCharging
//                        }
                    } // Section
                    
                    
                    if (isCharging){
                        Spacer().frame(width: 30)

                        Section(header: Text("Auto").bold()){
                            HStack(alignment: .bottom, spacing: 0) {
                                Spacer()
                                VStack(){
                                    Text(mqttVehicleRange + "\n" + mqttVehicleSoc + " %\n" + mqttVehicleOdometer)
                                        .multilineTextAlignment(.trailing)
                                        .frame(minHeight: 60)
                                }
//                                .alert(isPresented: $isCharging){
//                                    Alert(title: Text(isCharging ? "Auto lädt" : "Auto lädt nicht"))
//                                }
                            }
//                            .animation(SwiftUI.Animation?)
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

                    Text("Mit MQTT Server verbinden")
                    
                    Spacer()
                    
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(isConnected ? .orange : .secondary)
                    
                    Spacer()
                    
                    Toggle(isOn: self.$isConnected){
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: isConnected) { value in
//                        print("in onChange value: \(value)")
                        _ = mqttDoConnect(doConnect: value)
                    }
                    .onReceive(timer) { _ in
                        self.mqtt.didConnectAck = { mqtt, ack in
                            mqttSettings()
                            self.mqtt.didReceiveMessage = { mqtt, message, id in
                                processMessages(message: message)
                            }
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
        .frame(minWidth: 400, minHeight: 315)

        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

/// seperate Model from View
/// https://letscode.thomassillmann.de/model-logik-in-swiftui-views/
extension ContentView {
    
    func mqttDoConnect(doConnect: Bool) -> Bool{
//        print("mqttDoConnect(\(doConnect))")
        if (doConnect == true) {
            isConnected = self.mqtt.connect()
            print("mqttDoConnect -> isConnected: \(isConnected)")
        } else {
            self.mqtt.disconnect()
            isConnected = false
            print ("mqttDoConnect -> isConnected : \(isConnected)")
        }
        return false
    }
    
    func mqttSettings() {
//        self.mqtt.logLevel = .debug
        self.mqtt.username = "***"
        self.mqtt.password = "***"
        /// https://github.com/emqx/CocoaMQTT/issues/502
        self.mqtt.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
        self.mqtt.keepAlive = 60
        self.mqtt.enableSSL = false
//        self.mqtt.delegate = self
        self.mqtt.autoReconnect = true
        
        //self.mqtt.subscribe("#")
        self.mqtt.subscribe("evcc/site/#")
        self.mqtt.subscribe("evcc/loadpoints/1/#")
        self.mqtt.subscribe("smarthome/tele/tasmota7163/#")
        self.mqtt.subscribe("energy/growatt/modbusdata/#")
        print("mqttSettings() done.")
    }
    
    func processMessages(message: CocoaMQTTMessage) {
        
//        print("[topic] : \(message.topic)")
        
        if (message.topic.contains("evcc/site/homePower")) {
            if (message.string != nil){
                self.mqttHomePowerLabel = ("\(message.string!) W")
                self.mqttHomePower = Double(String(message.string!))!
            }
        }
        
        if (message.topic.contains("evcc/site/gridPower")) {
            if (message.string != nil){
                self.mqttGridPower = Double(String(message.string!))!
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
            if (message.string != nil){
                let payload = message.string?.lowercased()
//                print("processMessages -> payload: \(String(describing: payload))")
                if (payload!.contains("true")) {
                    isCharging = true
                } else {
                    isCharging = false
                }
            }
//            print ("processMessages -> isCharging : \(isCharging)")
        }
        
        if (message.topic.contains("evcc/loadpoints/1/vehicleRange")) {
            if (message.string != nil){
                self.mqttVehicleRange = ("\(message.string!) km")
            }
        }
        if (message.topic.contains("evcc/loadpoints/1/vehicleSoc")) {
            if (message.string != nil){
                let soc = Double(String(message.string!))!
                self.mqttVehicleSoc = String(format: "%0.0f", soc)
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
        
        /// renew data for BarMark Chart
        data0.removeAll()
        var netzbezug = 0.0
        var einspeisung = 0.0
        let verbrauch = mqttHomePower
        if (mqttGridPower >= 0){
            netzbezug = mqttGridPower * (-1.0)
        } else {
            einspeisung = mqttGridPower * (-1)
        }
        let erzeugung = mqttPower * (-1.0)
        
        data0.append(EnergyBalance(source: "Netzbezug", val: Int(netzbezug)))
        data0.append(EnergyBalance(source: "Erzeugung", val: Int(erzeugung)))
        data0.append(EnergyBalance(source: "Einspeisung", val: Int(einspeisung)))
        data0.append(EnergyBalance(source: "Verbrauch", val: Int(verbrauch)))
    }
}
