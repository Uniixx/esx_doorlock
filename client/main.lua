ESX = nil
local isLockpicking = false

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while not ESX.GetPlayerData().job do
		Citizen.Wait(10)
	end

	ESX.PlayerData = ESX.GetPlayerData()

	-- Update the door list
	ESX.TriggerServerCallback('esx_doorlock:getDoorState', function(doorState)
		for index,state in pairs(doorState) do
			Config.DoorList[index].locked = state
		end
	end)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job) ESX.PlayerData.job = job end)

RegisterNetEvent('esx_doorlock:setDoorState')
AddEventHandler('esx_doorlock:setDoorState', function(index, state) Config.DoorList[index].locked = state end)

RegisterNetEvent('esx_doorlock:setDoorStateLockpick')
AddEventHandler('esx_doorlock:setDoorStateLockpick', function(index, state) Config.DoorList[index].beingLockpick = state end)

Citizen.CreateThread(function()
	while true do
		local playerCoords = GetEntityCoords(PlayerPedId())

		for k,v in ipairs(Config.DoorList) do
			v.isAuthorized = isAuthorized(v)

			if v.doors then
				for k2,v2 in ipairs(v.doors) do
					if v2.object and DoesEntityExist(v2.object) then
						if k2 == 1 then
							v.distanceToPlayer = #(playerCoords - GetEntityCoords(v2.object))
						end

						if v.locked and v2.objHeading and ESX.Math.Round(GetEntityHeading(v2.object)) ~= v2.objHeading then
							SetEntityHeading(v2.object, v2.objHeading)
						end
					else
						v.distanceToPlayer = nil
						v2.object = GetClosestObjectOfType(v2.objCoords, 1.0, v2.objHash, false, false, false)
					end
				end
			else
				if v.object and DoesEntityExist(v.object) then
					v.distanceToPlayer = #(playerCoords - GetEntityCoords(v.object))

					if v.locked and v.objHeading and ESX.Math.Round(GetEntityHeading(v.object)) ~= v.objHeading then
						SetEntityHeading(v.object, v.objHeading)
					end
				else
					v.distanceToPlayer = nil
					v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
				end
			end
		end

		Citizen.Wait(500)
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local letSleep = true

		for k,v in ipairs(Config.DoorList) do
			if v.distanceToPlayer and v.distanceToPlayer < 50 then
				letSleep = false

				if v.doors then
					for k2,v2 in ipairs(v.doors) do
						FreezeEntityPosition(v2.object, v.locked)
					end
				else
					FreezeEntityPosition(v.object, v.locked)
				end
			end

			if v.distanceToPlayer and v.distanceToPlayer < v.maxDistance then
				local size, displayText = 1, _U('unlocked')

				if v.size then size = v.size end
				if v.locked then displayText = _U('locked') end
				if v.isAuthorized then 
					displayText = _U('press_button', displayText) 
				elseif not v.isAuthorized and v.locked and v.canLockpick and not isLockpicking and not v.beingLockpick then
					displayText = _U("press_button_lockpick") .. "\n" .. displayText
				elseif not v.isAuthorized and v.locked and v.canLockpick and isLockpicking and v.beingLockpick then
					displayText = "[E] pour arrêter" .. "\n" .. displayText
			    end

				ESX.Game.Utils.DrawText3D(v.textCoords, displayText, 0.5)

				if IsControlJustReleased(0, 38) then
					if v.isAuthorized then
						v.locked = not v.locked
						TriggerServerEvent('esx_doorlock:updateState', k, v.locked) -- broadcast new state of the door to everyone
					elseif not v.isAuthorized and v.canLockpick and v.locked and not isLockpicking and not v.beingLockpick then
						ESX.TriggerServerCallback("esx_doorlock:hasItem", function (hasItem) 
							if hasItem then
								startLockpick(v, k)
							else
								ESX.ShowNotification(_U("no_lockpick"))
							end
						end, "lockpick")
					elseif not v.isAuthorized and v.canLockpick and v.locked and isLockpicking then
						ForceStop(k)	
					elseif not v.isAuthorized and v.canLockpick and not v.locked and isLockpicking then
						ForceStop(k)		
					end
				end
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)

function ForceStop(index) 
	isLockpicking = false
	TriggerServerEvent('esx_doorlock:updateLockpick', index, false) 
    exports['progressBars']:closeUI()
    ClearPedTasksImmediately(GetPlayerPed(-1))
end

function startLockpick(door, index)
	local chance = math.random(1, 6)
	local playerPed = GetPlayerPed(-1)
	local coords = GetEntityCoords(playerPed)
	local waitTime = Config.LockpickTime * 1000
	local message = ""

	TriggerServerEvent('esx_doorlock:updateLockpick', index, true)

	isLockpicking = true

	playAnim()

	 if door.objHash and door.objHash == 631614199 then
		waitTime = (Config.LockpickTime * 1000) + (Config.CellLockpickTime * 1000)
	 end

	exports['progressBars']:startUI(waitTime, _U("lockpicking"))
	Citizen.Wait(waitTime)	

	if chance == 1 or chance == 2 then
		changeDoorState(index, door)
		message = _U("success")
	elseif chance == 3 then
		Citizen.Wait(100)
		ESX.ShowNotification(_U("overtime"))
		exports['progressBars']:startUI(Config.LockpickOvertime * 1000, _U("lockpicking"))
		Citizen.Wait(Config.LockpickOvertime * 1000)
		changeDoorState(index, door)
		message = _U("success")
	else
		isLockpicking = false
		TriggerServerEvent('esx_doorlock:updateLockpick', index, false) 
		message = _U("failed")
	end

	ESX.ShowNotification(message)

	ClearPedTasksImmediately(GetPlayerPed(-1))
	TriggerServerEvent('esx_doorlock:removeItem', 'lockpick', 1)
end

function changeDoorState(index, door)
	if not isLockpicking then return end
	isLockpicking = false
	door.locked = not door.locked
	TriggerServerEvent('esx_doorlock:updateLockpick', index, false) 
	TriggerServerEvent('esx_doorlock:updateState', index, door)
end

function playAnim()
	RequestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        while not HasAnimDictLoaded('anim@amb@clubhouse@tutorial@bkr_tut_ig3@') do
            Citizen.Wait(0)
        end
	 TaskPlayAnim(GetPlayerPed(-1), 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@' , 'machinic_loop_mechandplayer' ,8.0, -8.0, -1, 1, 0, false, false, false)
end

function isAuthorized(door)
	if not ESX or not ESX.PlayerData.job then
		return false
	end

	for k,job in pairs(door.authorizedJobs) do
		if job == ESX.PlayerData.job.name then
			return true
		end
	end

	return false
end
