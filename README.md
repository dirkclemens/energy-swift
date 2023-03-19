# energy-swift

macOS Swift (5.x) App using MQTT to show data from some of my energy sources (first approach)

Data sources: 
* Growatt inverter
* go-eCharger Homefix
* OBIS / SML reader (esp8266 based)

<img width="512" alt="screenshot" src="https://user-images.githubusercontent.com/908446/226187039-3ccbb406-1f1e-4c78-bdd4-ff189f04bb8b.png">

## Building using xcode 14

Install using Carthage (https://github.com/Carthage/Carthage) by adding the following lines to your `Cartfile`:

```
github "emqx/CocoaMQTT" "master"
github "SwiftyJSON/SwiftyJSON" ~> 4.0

Then, run the following command:

`carthage update --platform macOS --use-xcframeworks` or
`carthage update --use-xcframeworks`

## Integration of the libraries

On your application targets “General” settings tab, in the "Frameworks, Libraries, and Embedded content" section, drag and drop LibraryName.xcframework, from the Carthage/Build folder on disk. Then select "Embed & Sign". 
