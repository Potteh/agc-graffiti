Config = {}
Config.SprayItem = 'spraycan'
Config.CleanItem = 'graffiti_remover'
Config.MaxDistance = 3.0
Config.RenderDistance = 45.0
Config.MaxGraffiti = 400
Config.MaxPerPlayer = 20
Config.SprayDuration = 6500
Config.CleanDuration = 5500
Config.DispatchChance = 40 -- percent
Config.DispatchJobs = {police = true, sheriff = true}
Config.DispatchCooldown = 120 -- seconds per player
Config.MaxTextLength = 32
Config.MaxImageUrlLength = 500
Config.AllowCustomImageUrls = true
Config.AllowedImageHosts = {} -- Empty = any HTTPS hostname. For public servers, populate e.g. {'i.imgur.com'}.
Config.AllowedArtwork = {
    {label='Skull', url='https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/1f480.svg'},
    {label='Fire', url='https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/1f525.svg'},
    {label='Star', url='https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/2b50.svg'}
}
Config.AdminPermission = 'admin'
Config.DefaultScale = 1.0
Config.MinScale = 0.5
Config.MaxScale = 1.7
Config.DrawWidth = 0.65
Config.DrawHeight = 0.38
Config.PlaceCommand = 'graffiti'
Config.AdminDeleteCommand = 'graffitidelete'
