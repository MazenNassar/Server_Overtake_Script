local requiredSpeed = 35
local json = require('json')

function script.prepare(dt)
    ac.debug("speed", ac.getCarState(1).speedKmh)
    return ac.getCarState(1).speedKmh > 60
end
local currentTime = os.clock()
local lastSendTime = 0
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore =  0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0
local DriftTracking = ac.getCarState(1)
local stored = { }
local playerScores = {}
local comboScore = 0
local overtakeScore = 0
local lastScore = 0
local lasttop = "test"
local lasttopscore = 0

stored.lasttop = ac.storage('lasttop', lasttop) --default value
stored.lasttopscore = ac.storage('lasttopscore', lasttopscore) --default value
lasttop = stored.lasttop:get()
lasttopscore = stored.lasttopscore:get()

stored.playerscore = ac.storage('playerscore', highestScore) --default value
highestScore = stored.playerscore:get()

local leaderboard = {}

ac.onSharedEvent("leaderboardData", function(data)
  leaderboard = json.decode(data)
end)

local function getSharedLeaderboard()
  return leaderboard
end

function script.update(dt)

    local player = ac.getCarState(1)
    if player.engineLifeLeft < 1 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            stored.playerscore:set(highestScore)
        end
		if totalScore > 50 then
				lastScore = math.floor(totalScore)
		end
        comboScore = 0
        overtakeScore = 0
        totalScore = 0
        comboMeter = 1
        return
    end

    timePassed = timePassed + dt

    local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

    local sim = ac.getSimState()
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = {}
    end

    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        addMessage("Car is outside", -1)
        wheelsWarningTimeout = 60
    end
    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 3 then
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            stored.playerscore:set(highestScore)
        end
			if totalScore > 50 then
				lastScore = math.floor(totalScore)
			end
            comboScore = 0
            overtakeScore = 0
            totalScore = 0
            comboMeter = 1
        else
        end

        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        return
    else
        dangerouslySlowTimer = 0
    end

    for i = 1, ac.getSimState().carsCount do
        local car = ac.getCarState(i)
        local state = carsState[i]

        if car.pos:closerToThan(player.pos, 10) then
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
                    state.nearMiss = true
                    comboMeter = comboMeter + 1
                end
            end

            if car.collidedWith == 0 then
                state.collided = true
				if totalScore > highestScore then
                	highestScore = math.floor(totalScore)
                    stored.playerscore:set(highestScore)
                end
                comboScore = 0
                overtakeScore = 0
				if totalScore > 50 then
					lastScore = math.floor(totalScore)
				end
                totalScore = 0
                comboMeter = 1
            end

            if DriftTracking.isDriftValid then
                        local points = math.ceil(1 * comboMeter)
                        comboScore = comboScore + points
                        totalScore = comboScore + overtakeScore
                        comboMeter = comboMeter + 0.02
                        comboColor = comboColor + 5
                        end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.pos - player.pos):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                                local points = math.ceil(10 * comboMeter)
                                overtakeScore = overtakeScore + points
                                totalScore = comboScore + overtakeScore
                                comboMeter = comboMeter + 1
                                comboColor = comboColor + 10
                                state.overtaken = true
                                end
            end
        else
            state.maxPosDot = -1
            state.overtaken = false
            state.collided = false
            state.drivingAlong = true
            state.nearMiss = false
        end
    end
		local cnt = ac.getSimState().carsCount
        if os.clock() - lastSendTime > 2 then
  			lastSendTime = os.clock()
  			ac.broadcastSharedEvent("scoreUpdate", json.encode({
    			name = ac.getDriverName(0),
    			drift = comboScore,
    			overtake = overtakeScore,
    			total = totalScore,
    			highest = highestScore
  			}))
		end
end


local messages = {}

function addMessage(text, mood)
    for i = math.min(#messages + 1, 4), 2, -1 do
        messages[i] = messages[i - 1]
        messages[i].targetPos = i
    end
    messages[1] = {text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood}
    if mood == 1 then
        for i = 1, 60 do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
        end
    end
end

local function updateMessages(dt)
    comboColor = comboColor + dt * 10 * comboMeter
    if comboColor > 360 then
        comboColor = comboColor - 360
    end
    for i = 1, #messages do
        local m = messages[i]
        m.age = m.age + dt
        m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
    end
    if comboMeter > 10 and math.random() > 0.98 then
        for i = 1, math.floor(comboMeter) do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
        end
    end
end
local speedWarning = 0
    local function getSortedLeaderboard()
        local list = {}
        for _, data in pairs(playerScores) do
			if data.name and data.name ~= "" then
                table.insert(list, data)
			end
        end
        table.sort(list, function(a, b) return a.highest > b.highest end)
        return list
    end

    function script.drawUI()
        local uiState = ac.getUiState()
        updateMessages(uiState.dt)

        local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
        speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

        local colorDark = rgbm(0.4, 0.4, 0.4, 1)
        local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
        local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
        local colorCombo =
            rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))
        local function speedMeter(ref)
            ui.drawRectFilled(ref + vec2(0, -4), ref + vec2(180, 5), colorDark, 1)
            ui.drawLine(ref + vec2(0, -4), ref + vec2(0, 4), colorGrey, 1)
            ui.drawLine(ref + vec2(requiredSpeed, -4), ref + vec2(requiredSpeed, 4), colorGrey, 1)

            local speed = math.min(ac.getCarState(1).speedKmh, 180)
            if speed > 1 then
                ui.drawLine(ref + vec2(0, 0), ref + vec2(speed, 0), colorAccent, 4)
            end
        end
        ui.beginTransparentWindow("overtakeScore", vec2(600, 100), vec2(600, 600))
        ui.beginOutline()

		ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
        ui.pushFont(ui.Font.Main)
        ui.textColored("Racing Server", colorCombo)
        ui.popFont()
        ui.pushFont(ui.Font.Title)
        local white = rgbm(1, 1, 1, 1)
        ui.textColored("Highest Score: " .. highestScore .. " pts", white)
		ui.textColored("Last Score: " .. lastScore .. " pts", white)
        ui.textColored("Total Score: " .. totalScore .. " pts", white)
        ui.textColored("Drift Score: " .. comboScore .. " pts", white)
        ui.textColored("Overtake Score: " .. overtakeScore .. " pts", white)
        ui.textColored(string.format("Combo: %.1fx", comboMeter), white)
        ui.offsetCursorY(30)
        ui.text("Leaderboard")
        local leaderboard = getSharedLeaderboard()
        local localIndex = nil
        for i, entry in ipairs(leaderboard) do
        	if entry.isLocal then
        		localIndex = i
        		break
        	end
        end
        for i, entry in ipairs(leaderboard) do
        	local shouldDisplay = i <= 3 or i == localIndex - 1 or i == localIndex or i == localIndex + 1
        	if shouldDisplay then
        		local color = entry.isLocal and rgbm(1, 1, 0, 1) or rgbm(1, 1, 1, 1)
				if i==1 and entry.name ~= lasttop and entry.highest ~= lasttopscore then
					lasttop = entry.name
					lasttopscore = entry.highest
					stored.lasttop:set(lasttop)
					stored.lasttopscore:set(lasttopscore)
					ac.sendChatMessage("Driver: " .. entry.name .. " is now the TOP 1 server wide with highest score: " .. entry.highest .. " pts")
				end
        		ui.textColored(i .. ". " .. entry.name, color)
        		ui.text("   Highest: " .. entry.highest .. "  |  Total: " .. entry.total .. "  |  Drift: " .. entry.drift .. "  |  Overtake: " .. entry.overtake)

        	end
        end
        ui.popFont()
        ui.popStyleVar()

        ui.endOutline(rgbm(0, 0, 0, 0.3))

        ui.offsetCursorY(20)
        ui.pushFont(ui.Font.Main)
        local startPos = ui.getCursor()
        for i = 1, #messages do
            local m = messages[i]
            local f = math.saturate(4 - m.currentPos) * math.saturate(8 - m.age)
            ui.setCursor(startPos + vec2(20 * 0.5 + math.saturate(1 - m.age * 10) ^ 2 * 50, (m.currentPos - 1) * 15))
            ui.textColored(
                m.text,
                m.mood == 1 and rgbm(0, 1, 0, f) or m.mood == -1 and rgbm(1, 0, 0, f) or rgbm(1, 1, 1, f)
            )
        end
        ui.popFont()
        ui.setCursor(startPos + vec2(0, 4 * 30))

        ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
        ui.setCursorY(0)
        ui.pushFont(ui.Font.Main)
        ui.textColored("Keep speed above " .. requiredSpeed .. " km/h:", colorAccent)
        speedMeter(ui.getCursor() + vec2(-9 * 0.5, 4 * 0.2))

        ui.popFont()
        ui.popStyleVar()

        ui.endTransparentWindow()
    end
