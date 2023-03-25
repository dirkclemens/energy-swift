# energy-swift

macOS & iOS Swift (5.x) App using MQTT to show data from some of my energy sources (first approach)

Data sources: 
* Growatt inverter
* go-eCharger Homefix
* OBIS / SML reader (esp8266 based)

<img width="453" alt="screenshot" src="https://user-images.githubusercontent.com/908446/227708215-72c07d55-e73d-40a1-a18a-d3179d9b2aeb.png">


## Building using xcode 14

Install using Carthage (https://github.com/Carthage/Carthage) by adding the following lines to your `Cartfile`:

```
github "emqx/CocoaMQTT" "master"
github "SwiftyJSON/SwiftyJSON" ~> 4.0
```

Then, run the following command:

`carthage update --platform macOS,iOS --use-xcframeworks` or   
`carthage update --use-xcframeworks`


## Integration of the libraries

On your application targets “General” settings tab, in the "Frameworks, Libraries, and Embedded content" section, drag and drop LibraryName.xcframework, from the Carthage/Build folder on disk. Then select "Embed & Sign". 

![framworks-512x172](https://user-images.githubusercontent.com/908446/226188479-2cbd7b41-9de9-42d0-8e1e-dbe340ebbebb.png)
