//
//  ContentView.swift
//  Energiebilanz
//
//  Created by Dirk Clemens on 24.03.23.
//
//  icon made with: https://www.appicon.co/#app-icon


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
        var value: Int
    }
    @State var barMarkData: [EnergyBalance] = [
        .init(source: "Netzbezug", value: 0),
        .init(source: "Erzeugung", value: 0),
        .init(source: "Einspeisung", value: 0),
        .init(source: "Verbrauch", value: 0)
    ]
    
    struct MqttData {
        var source: String
        let date: Date
        let value: Double
     
        init(source: String, value: Double) {
            self.source = source
            self.date = Date.now
            self.value = value
        }
    }
    @State var lineMarkData: [MqttData] = [
        .init(source: "Netzbezug", value: 0.0),
        .init(source: "Erzeugung", value: 0.0),
        .init(source: "Einspeisung", value: 0.0),
        .init(source: "Verbrauch", value: 0.0)
    ]
    let dataPoints = 149

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
    @State var mqttSMLLabel = "- kWh\n- kWh"        //smarthome/tele/tasmota7163/SENSOR     --> SML
    @State var mqttSMLLabel167 = "- Wh"             //smarthome/tele/tasmota7163/SENSOR     --> SML

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

            Chart(lineMarkData, id: \.source) { element in
                
                LineMark(
                    x: .value("Zeit", element.date),
                    y: .value("Wert", element.value)
                )
                .foregroundStyle(by: .value("Quelle", element.source))
//                .symbol {
//                    Circle().fill(by: .yellow).frame(width: 4)
//                }
                
                PointMark( // with PointMarks, the annotation will attach to the individual point
                    x: .value("Zeit", element.date),
                    y: .value("Wert", element.value)
                )
                .interpolationMethod(.catmullRom)
//                .symbolSize(0) // hide the existing symbol
                .symbolSize(10)
//                .symbol(by: .value("Quelle", element.source))
                .foregroundStyle(by: .value("Quelle", element.source))
//                .position(by: .value("Quelle", element.source))
                
//                .annotation(position: .top, alignment: .trailing, spacing: 26) {
//                    Text(String(format: "%.1f W", element.value))
//                        .font(.caption)
//                }
            }
            .chartLegend(position: .bottom, alignment: .center)
            .chartLegend(.hidden)
            .chartYAxisLabel("W")
            .chartForegroundStyleScale([
                "Netzbezug" : steelBlue,
                "Erzeugung": .orange,
                "Einspeisung": lemonYellow,
                "Verbrauch" : evccGreen]
            )
            .frame(height: 100)

            Divider().frame(height: 2)

            HStack {
                Text("IN")
                    .foregroundColor(.secondary).bold()
                Spacer()
                Text("OUT")
                    .foregroundColor(.secondary).bold()
            }
            Chart(barMarkData, id: \.source) { element in
                BarMark(
                    x: .value("Energiebilanz", element.value)
                )
                .foregroundStyle(by: .value("Quelle", element.source))
                .annotation(position: .overlay, alignment: .center) {
                    Text("\(element.value) W").font(.caption)
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
        //------------------------------------------------------------------------
        .task { // https://stackoverflow.com/a/66802353/10590793
            debug(text: "task(id:priority:_:) has been called ...")
            self.mqtt.didConnectAck = { mqtt, ack in
                debug(text: "task(id:priority:_:) didConnectAck ...")
                mqttSettings()
            }
            self.mqtt.didReceiveMessage = { mqtt, message, id in
                debug(text: "task(id:priority:_:) didReceiveMessage ...")
                processMessages(message: message)
            }
        }
        //------------------------------------------------------------------------
        .onReceive(timer) { _ in // https://github.com/emqx/CocoaMQTT/issues/444#issuecomment-1072787295
//            debug(text: "onReceive(timer) has been called ...")
            self.mqtt.didConnectAck = { mqtt, ack in
//                debug(text: "onReceive() didConnectAck ...")
                mqttSettings()
            }
            self.mqtt.didReceiveMessage = { mqtt, message, id in
//                debug(text: "onReceive() didReceiveMessage ...")
                processMessages(message: message)
            }
//            self.mqtt.didConnectAck = { mqtt, ack in
//                mqttSettings()
//                self.mqtt.didReceiveMessage = { mqtt, message, id in
//                    processMessages(message: message)
//                }
//            }
        }
        //------------------------------------------------------------------------
        .onLoad {
            debug(text: "View().onLoad")
            mqttSettings()
        }
        //------------------------------------------------------------------------
        .onAppear {
            debug(text: "View().onAppear -> isConnected: \(isConnected)")
//            if (isConnected == true){
//                self.mqtt.disconnect()
//            } else {
//                _ = mqttDoConnect(doConnect: true)
//            }
        }
        //------------------------------------------------------------------------
        .onDisappear {
            debug(text: "View().onDisappear")
            self.mqtt.disconnect()
        }
        //------------------------------------------------------------------------
        .padding()
        .frame(minHeight: 240)
//        .frame(minWidth: 350, minHeight: 240)
//        .frame(maxWidth: 360)


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
                        Text(mqttEnergyTotalLabel) // + 27459
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
#if os(macOS)
                            Spacer()
                            Text(mqttSMLLabel + "\n" + mqttSMLLabel167)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(3)
                            #else
                            Spacer()
                            Text(mqttSMLLabel167)
//                                .multilineTextAlignment(.trailing)
//                            Spacer()
//                            Text(mqttSMLLabel)
//                                .multilineTextAlignment(.trailing)
//                                .frame(minHeight: 50)
                            #endif
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
#if os(macOS)
                                    Text(mqttVehicleRange + "\n" + mqttVehicleSoc + " %\n" + mqttVehicleOdometer)
                                        .multilineTextAlignment(.trailing)
                                        .lineLimit(3)
                                    #else
                                    Text(mqttVehicleRange + "\n" + mqttVehicleSoc)
                                        .multilineTextAlignment(.trailing)
                                        .lineLimit(2)
                                    #endif
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
            
            Group {
                HStack(alignment: .center, spacing: 0) {

#if os(macOS)
                    Text("Mit MQTT Server verbinden:")
                    #else
                    Text("verbinden:")
                    #endif
                    
                    Spacer()
                    
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(isConnected ? .orange : .secondary)

                    Spacer()
                    
                    Toggle(isOn: self.$isConnected){
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: isConnected) { value in
//                        debug(text: "in onChange value: \(value)")
                        _ = mqttDoConnect(doConnect: value)
                    }
                } // HStack
            } // Group
        } // VStack
        .padding(10)
//        .padding(.bottom, 0)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.gray, lineWidth: 0.2)
//                .padding(15)
        )
        .padding(.leading, 15)
        .padding(.trailing, 15)
        .frame(minHeight: 320)
//        .frame(minWidth: 350, minHeight: 320)
//        .frame(maxWidth: 350)

#if os(iOS)
        HStack(alignment: .bottom, spacing: 0) {
            Text("made with ")
            Image(systemName: "apple.logo")
            Text(" by dirk c.")
        }
#else
        Spacer()

#endif
    } // View
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

/// seperate Model from View
/// https://letscode.thomassillmann.de/model-logik-in-swiftui-views/
extension ContentView {
    
    func debug(text: String) {
//        print("[\(Date(), formatter: Formatter.mediumTime)] \(text)")
    }
    
    func mqttDoConnect(doConnect: Bool) -> Bool{
//        debug(text: "mqttDoConnect(\(doConnect))")
        if (doConnect == true) {
            isConnected = self.mqtt.connect()
            debug(text: "mqttDoConnect -> isConnected: \(isConnected)")
        } else {
            self.mqtt.disconnect()
            isConnected = false
            debug(text: "mqttDoConnect -> isConnected : \(isConnected)")
        }
        return isConnected
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
        
//        self.mqtt.subscribe("#")
//        self.mqtt.subscribe("evcc/site/#")
        self.mqtt.subscribe("evcc/site/homePower")
        self.mqtt.subscribe("evcc/site/gridPower")
        self.mqtt.subscribe("evcc/site/pv/1/power")
        self.mqtt.subscribe("evcc/loadpoints/1/#")
        self.mqtt.subscribe("smarthome/tele/tasmota7163/#")
        self.mqtt.subscribe("energy/growatt/modbusdata/#")
        debug(text: "mqttSettings() done.")
    }
    
    func processMessages(message: CocoaMQTTMessage) {
        
//        debug(text: "[topic] : \(message.topic)")
        
        if (message.topic.contains("evcc/site/homePower")) {
            if (message.string != nil){
                self.mqttHomePowerLabel = ("\(message.string!) W")
                self.mqttHomePower = Double(String(message.string!))!
                
                // append data for LineMark Chart
                let cnt = lineMarkData.count
                if (cnt > dataPoints) {
                    lineMarkData.removeFirst()
                }
                lineMarkData.append(MqttData(source: "Verbrauch", value: self.mqttHomePower))
                debug(text: "element appended to chartData / Verbrauch: \(self.mqttHomePower), count: \(cnt)")
            }
        }
        
        if (message.topic.contains("evcc/site/gridPower")) {
            if (message.string != nil){
                self.mqttGridPower = Double(String(message.string!))!

                // append data for LineMark Chart
                let cnt = lineMarkData.count
                if (cnt > dataPoints) {
                    lineMarkData.removeFirst()
                }

                if self.mqttGridPower < 0 {
                    self.mqttGridInPowerLabel = ("0 W")
                    self.mqttGridInPower = 0.0
                    self.mqttGridOutPowerLabel = ("\(message.string!) W")
                    self.mqttGridOutPower = Double(String(message.string!))!
                    lineMarkData.append(MqttData(source: "Einspeisung", value: self.mqttGridOutPower))
                    debug(text: "element appended to chartData / Einspeisung: \(self.mqttGridOutPower)")
                }
                else{
                    self.mqttGridInPowerLabel = ("\(message.string!) W")
                    self.mqttGridInPower = Double(String(message.string!))!
                    self.mqttGridOutPowerLabel = ("0 W")
                    self.mqttGridOutPower = 0.0
                    lineMarkData.append(MqttData(source: "Netzbezug", value: self.mqttGridInPower))
                    debug(text: "element appended to chartData / Netzbezug: \(self.mqttGridInPower)")
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
//                debug(text: "processMessages -> payload: \(String(describing: payload))")
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
                    
                    let outputpowerString = json?["outputpower"].stringValue
                    let outputpower = Double(String(outputpowerString!))!
                    self.mqttOutputPowerLabel = ("\(String(format: "%0.0f", outputpower)) W")

                    self.mqttEnergyTodayLabel = ("\(json?["energytoday"].stringValue ?? "") kW")
                    
                    let totalString = json?["energytotal"].stringValue
                    let total = Double(String(totalString!))! + 27459.0
                    self.mqttEnergyTotalLabel = ("\(String(format: "%0.0f", total)) kW")
                }
            }
        }
        
        if (message.topic.contains("evcc/site/pv/1/power")) {
            if (message.string != nil){
                self.mqttPowerLabel = ("\(message.string!) W")
                self.mqttPower = Double(String(message.string!))!
                
                // append data for LineMark Chart
                let cnt = lineMarkData.count
                if (cnt > dataPoints) {
                    lineMarkData.removeFirst()
//                    debug(text: "element removed from chartData")
                }
                lineMarkData.append(MqttData(source: "Erzeugung", value: self.mqttPower))
                debug(text: "element appended to chartData / Erzeugung: \(self.mqttPower), count: \(cnt)")
            }
        }
        
        if (message.topic.contains("smarthome/tele/tasmota7163/SENSOR")) {
            if (message.string != nil){
                let payload = String(message.string!)
                if let dataFromString = payload.data(using: .utf8, allowLossyConversion: false) {
                    let json = try? JSON(data: dataFromString)
                    let str = ("\(json?["SML"]["Total_in"].stringValue ?? "") kWh \n\(json?["SML"]["Total_out"].stringValue ?? "") kWh")
                    self.mqttSMLLabel = str
                    self.mqttSMLLabel167 = ("\(json?["SML"]["Power_curr"].stringValue ?? "") Wh")
                }
            }
        }
        
        // renew data for BarMark Chart
        barMarkData.removeAll()
        var netzbezug = 0.0
        var einspeisung = 0.0
        let verbrauch = mqttHomePower
        if (mqttGridPower >= 0){
            netzbezug = mqttGridPower * (-1.0)
        } else {
            einspeisung = mqttGridPower * (-1)
        }
        let erzeugung = mqttPower * (-1.0)
        
        barMarkData.append(EnergyBalance(source: "Netzbezug", value: Int(netzbezug)))
        barMarkData.append(EnergyBalance(source: "Erzeugung", value: Int(erzeugung)))
        barMarkData.append(EnergyBalance(source: "Einspeisung", value: Int(einspeisung)))
        barMarkData.append(EnergyBalance(source: "Verbrauch", value: Int(verbrauch)))
                
    }
}

// https://www.ralfebert.de/ios/swift-dateformatter-datumsangaben-formatieren/
extension DefaultStringInterpolation {
    mutating func appendInterpolation(_ value: Date, formatter: DateFormatter) {
        self.appendInterpolation(formatter.string(from: value))
    }
}
struct Formatter {

    /// 12:34
    static let mediumTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    /// 12.03.2021
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// 12.03.2021 12:34
    static let mediumDateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

}
