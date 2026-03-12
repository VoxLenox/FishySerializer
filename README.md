# 🐟 What's Fishy Serializer
Fishy serializer is a simple instance serialization plugin I made for Roblox. Unlike other several free serializer plugins, Fishy Serializer isn't outdated and it probably gonna stay updated for a long while even without maintenance. Beside serializing properties, this plugin also serialize attributes and tags. Relied entirely on Engine APIs ([ReflectionService](https://create.roblox.com/docs/reference/engine/classes/ReflectionService) and [SerializationService](https://create.roblox.com/docs/reference/engine/classes/SerializationService))

# 🤔 Why're there two version?
They're both output Luau code but there a key difference in the format of the outputted code
### Standard version
This is the recommended version as it's the most stable one, it use the same create-and-set format like other serializers, all data are retrieved from `ReflectionService`. You can get the Roblox plugin of this version [here](https://create.roblox.com/store/asset/79742565115725)
### Binary version
This one use `SerializationService` to convert instances into byte codes (in RBXM format) and then those byte codes get converted into unicodes and then it all get shoved into one script along with the deserialization codes. Although serializing this way will give zero instance mismatch-ness when you deserialize but it is very unstable according to this [documentation](https://create.roblox.com/docs/reference/engine/classes/SerializationService). You can get the Roblox plugin of this version [here](https://create.roblox.com/store/asset/114422747919615)
