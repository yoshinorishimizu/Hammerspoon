-- Constants
local MODAL_KEYS = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                    "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
                    "A", "S", "D", "F", "G", "H", "J", "K", "L",
                    "Z", "X", "C", "V", "B", "N", "M"}

local BROWSER_PROFILES = {
    -- {Profile Directory, Display Name, Browser Type}
    {"Profile 1", "Chrome", "chrome"},
    {"Profile 2", "Chrome", "chrome"},
    {"", "Safari", "safari"}  -- Safari doesn't need a profile directory
}

-- UI Configuration
local UI_CONFIG = {
    boxBorder = 10,
    iconSize = 96,
    iconMargin = 25,
    backgroundColor = {red = 0, blue = 0, green = 0, alpha = 0.8},
    overlayColor = {red = 0, blue = 0, green = 0, alpha = 0.4},
    textStyle = {
        size = 10,
        color = {red = 1, blue = 1, green = 1, alpha = 1},
        alignment = "center",
        lineBreak = "truncateMiddle"
    }
}

-- Helper Functions
local function calculatePosition(screen, numProfiles, config)
    return {
        x = screen.x + (screen.w / 2) - (numProfiles * config.iconSize / 2),
        y = screen.y + (screen.h / 2) - (config.iconSize / 2)
    }
end

local function createBackgroundOverlay(screen)
    local bg = hs.drawing.rectangle(hs.geometry.rect(0, 0, screen.x + screen.w, screen.y + screen.h))
    bg:setFillColor(UI_CONFIG.overlayColor):setFill(true):show()
    return bg
end

local function createSelectionBox(pos, numProfiles, config)
    local box = hs.drawing.rectangle(hs.geometry.rect(
        pos.x - config.boxBorder,
        pos.y - config.boxBorder,
        (numProfiles * config.iconSize) + (config.boxBorder * 2),
        config.iconSize + (config.boxBorder * 4)
    ))
    box:setFillColor(config.backgroundColor):setFill(true):show()
    box:setRoundedRectRadii(10, 10)
    return box
end

local function openBrowser(profile, browserType, url)
    if browserType == "chrome" then
        hs.task.new("/usr/bin/open", nil, {
            "-n",
            "-a", "Google Chrome",
            "--args",
            "--profile-directory=" .. profile,
            url
        }):start()
    elseif browserType == "safari" then
        hs.task.new("/usr/bin/open", nil, {
            "-a", "Safari",
            url
        }):start()
    end
end

local function getProfileIcon(profile, browserType)
    if browserType == "chrome" then
        return hs.image.imageFromPath(
            string.format("~/Library/Application Support/Google/Chrome/%s/Google Profile Picture.png", profile)
        )
    elseif browserType == "safari" then
        -- SafariのアプリケーションアイコンをロードPu
        return hs.image.imageFromAppBundle("com.apple.Safari")
    end
    return nil
end

local function createProfileSelector()
    local elements = {
        icons = {},
        names = {},
        modalDirector = hs.hotkey.modal.new()
    }

    local function cleanup(profile, browserType, url, previousWindow)
        for _, icon in pairs(elements.icons) do icon:delete() end
        for _, name in pairs(elements.names) do name:delete() end
        elements.box:delete()
        elements.bg:delete()
        elements.modalDirector:exit()

        if profile and browserType and url then
            openBrowser(profile, browserType, url)
        else
            previousWindow:focus()
        end
        previousWindow:delete()
    end

    return {
        elements = elements,
        cleanup = cleanup
    }
end

-- Main URL Event Handler
hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
    local previousWindow = hs.window.frontmostWindow()
    local screen = hs.screen.mainScreen():frame()
    local numProfiles = #BROWSER_PROFILES

    if numProfiles == 0 then return end

    local selector = createProfileSelector()
    local pos = calculatePosition(screen, numProfiles, UI_CONFIG)

    selector.elements.bg = createBackgroundOverlay(screen)
    selector.elements.box = createSelectionBox(pos, numProfiles, UI_CONFIG)
    selector.elements.box.orderAbove(selector.elements.bg)

    -- Set background click handler
    selector.elements.bg:setClickCallback(function()
        selector.cleanup(nil, nil, nil, previousWindow)
    end)

    -- Create browser icons and handlers
    for num, profile in pairs(BROWSER_PROFILES) do
        local appImg = getProfileIcon(profile[1], profile[3])

        if appImg then
            local icon = hs.drawing.image(
                hs.geometry.size(UI_CONFIG.iconSize - UI_CONFIG.iconMargin, UI_CONFIG.iconSize - UI_CONFIG.iconMargin),
                appImg
            )
            local name = hs.drawing.text(
                hs.geometry.size(UI_CONFIG.iconSize, UI_CONFIG.boxBorder * 2),
                MODAL_KEYS[num] .. " " .. profile[2]
            )

            table.insert(selector.elements.icons, icon)
            table.insert(selector.elements.names, name)

            -- Position and style icon
            icon:setTopLeft(hs.geometry.point(
                pos.x + ((num - 1) * UI_CONFIG.iconSize) + UI_CONFIG.iconMargin/2,
                pos.y + UI_CONFIG.iconMargin/2
            ))
            icon:setClickCallback(function()
                selector.cleanup(profile[1], profile[3], fullURL, previousWindow)
            end)
            icon:orderAbove(selector.elements.box)
            icon:show()

            -- Position and style name
            name:setTopLeft(hs.geometry.point(
                pos.x + ((num - 1) * UI_CONFIG.iconSize),
                pos.y + UI_CONFIG.iconSize
            ))
            name:setTextStyle(UI_CONFIG.textStyle)
            name:orderAbove(selector.elements.box)
            name:show()

            -- Add keyboard shortcut
            selector.elements.modalDirector:bind({}, MODAL_KEYS[num], function()
                selector.cleanup(profile[1], profile[3], fullURL, previousWindow)
            end)
        end
    end

    -- Add escape key handler
    selector.elements.modalDirector:bind({}, "Escape", function()
        selector.cleanup(nil, nil, nil, previousWindow)
    end)
    selector.elements.modalDirector:enter()
end

-- Set as default HTTP handler
hs.urlevent.setDefaultHandler('http')