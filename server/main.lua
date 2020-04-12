ESX = nil
local doorState = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_doorlock:updateState')
AddEventHandler('esx_doorlock:updateState', function(doorIndex, state)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer and type(doorIndex) == 'number' and type(state) == 'boolean' and Config.DoorList[doorIndex] and isAuthorized(xPlayer.job.name, Config.DoorList[doorIndex]) then
		doorState[doorIndex] = state
		TriggerClientEvent('esx_doorlock:setDoorState', -1, doorIndex, state)
	end
end)

RegisterServerEvent('esx_doorlock:updateLockpick')
AddEventHandler('esx_doorlock:updateLockpick', function(doorIndex, state)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer and type(doorIndex) == 'number' and type(state) == 'boolean' and Config.DoorList[doorIndex] then
		doorState[doorIndex] = state
		TriggerClientEvent('esx_doorlock:setDoorStateLockpick', -1, doorIndex, state)
	end
end)

ESX.RegisterServerCallback("esx_doorlock:hasItem", function(source, cb, item)
    local xPlayer = ESX.GetPlayerFromId(source)
    local item = xPlayer.getInventoryItem(item)["count"]

    if item >= 1 then
        cb(true)
    else
        cb(false)
    end
end)

RegisterServerEvent("esx_doorlock:removeItem")
AddEventHandler('esx_doorlock:removeItem', function(item, count)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.removeInventoryItem(item, count)
end)

ESX.RegisterServerCallback('esx_doorlock:getDoorState', function(source, cb)
	cb(doorState)
end)

function isAuthorized(jobName, doorObject)
	for k,job in pairs(doorObject.authorizedJobs) do
		if job == jobName then
			return true
		end
	end

	return false
end
