-- HD2-Addon: mods/retrox/eat_airburst
local loader=rawget(_G,'CowboyBingusModLoader')
assert(loader and loader.api>=1 and loader.version>=16,'Bingus Shared Loader v15 or newer / API 1 required')
local name='mods/retrox/eat_airburst_impl'
assert(stingray.Application.can_get('lua',name),'EAT Airburst implementation missing')
return require(name)
