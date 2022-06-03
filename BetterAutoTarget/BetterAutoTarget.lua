--[[ 
    Based on enemybar2 addon by 'mmckee,akaden'
    Blanket liftet aggro tracking logic, planning to refine later
    as it's completely overkill and there should be better approaches.
 ]]

_addon.name = 'BetterAutoTarget'
_addon.author = 'Sunderous'
_addon.version = '1.0.0.0'
_addon.commands = {'bat'}

config = require('config')
packets = require('packets')
res = require('resources')

require('actionTracking')

--settings = config.load(defaults)

party_members = {}

windower.register_event('incoming chunk', function(id, data)
    -- NPC Update Packet
    if id == 0x00E then
        local packet = packets.parse('incoming', data)
        local mask = packet['Mask']

        -- If the third bit of the mask is set (00000100 = 4)
        -- That means it's an HP or Status update
        if(bit.band(0x04, mask) == 0x04) then
            local target = windower.ffxi.get_mob_by_target('t')
            local player = windower.ffxi.get_mob_by_target('me')
            if(target ~= nil) then
                if(packet['NPC'] == target.id) then
                    local hpp = packet['HP %']
                    
                    if(hpp == 0) then
                        local mobs = windower.ffxi.get_mob_array()

                        -- Try to target the first mob:
                        -- > Within 5 Yalms
                        -- > Unclaimed, or claimed by us.
                        for id, bar in pairs(tracked_enmity) do
                            local mob = windower.ffxi.get_mob_by_id(id)
                            -- TODO: Figure out best way to filter for actual monsters, then add blacklist functionality
                            if(is_npc(id) and get_distance(player, mob) < 10) then
                                -- Unclaimed
                                if(mob.claim_id == 0) then
                                    local p = packets.new('outgoing', 0x01A, {
                                        ['Target'] = mob.id,
                                        ['Target Index'] = mob.index,
                                        ['Category'] = 0x0F,
                                    })

                                    packets.inject(p)

                                    break
                                end
                            end
                        end
                        -- local nextTarget = windower.ffxi.get_mob_by_target('bt')
                        -- if(nextTarget ~= nill) then
                            
                        -- end
                    end
                    --windower.chat.input(string.format('/p Mob updated: %i', hpp))
                end
            end
        end
    end

    handle_action_packet(id, data)
    handle_party_packets(id, data)
end)

windower.register_event('prerender', clean_tracked_actions)
windower.register_event('zone change', reset_tracked_actions)

-- Party Stuff

function is_party_member_or_pet(mob_id)
    if mob_id == windower.ffxi.get_player().id then return true, 1 end

    if is_npc(mob_id) then return false end

    if party_members[mob_id] == nil then return false end

    return party_members[mob_id], party_members[mob_id].party
end

function handle_party_packets(id, data)
    if id == 0x0DD then
        -- cache party 
        cache_party_members:schedule(1)
    elseif id == 0x067 then
        local p =  packets.parse('incoming', data)
        if p['Owner Index'] > 0 then
            local owner = windower.ffxi.get_mob_by_index(p['Owner Index'])
            if owner and is_party_member_or_pet(owner.id) then
                party_members[p['Pet ID']] = {is_pet = true, owner = owner.id}
            end
        end
    end
end

function cache_party_members()
    party_members = {}
    local party = windower.ffxi.get_party()
    if not party then return end
    for i=0, (party.party1_count or 0) - 1 do
        cache_party_member(party['p'..i], 1)            
    end
    for i=0, (party.party2_count or 0) - 1 do
        cache_party_member(party['a1'..i], 2)            
    end
    for i=0, (party.party3_count or 0) - 1 do
        cache_party_member(party['a2'..i], 3)            
    end
end

function cache_party_member(p, party_number)
    if p and p.mob then
        party_members[p.mob.id] = {is_pc = true, party=party_number}
        if p.mob.pet_index then
            local pet = windower.ffxi.get_mob_by_index(p.mob.pet_index)
            if pet then
                party_members[pet.id] = {is_pet = true, owner = p.id, party=party_number}
            end
        end
    end
end

-- Helper functions from enemybar2 addon.
function get_distance(player, target)
    local dx = player.x-target.x
    local dy = player.y-target.y
    return math.sqrt(dx*dx + dy*dy)
end

function is_npc(mob_id)
    local is_pc = mob_id < 0x01000000
    local is_pet = mob_id > 0x01000000 and mob_id % 0x1000 > 0x700

    -- filter out pcs and known pet IDs
    if is_pc or is_pet then return false end

    -- check if the mob is charmed
    local mob = windower.ffxi.get_mob_by_id(mob_id)
    if not mob then return nil end
    return mob.is_npc and not mob.charmed
end

function check_claim(claim_id)
    if player_id == claim_id then
            return 1
    else
        local m, p = is_party_member_or_pet(claim_id)
        if m and p == 1 then
            return 2
        elseif m and p > 1 then
            return 3
        end
    end
    return 0
end

windower.register_event('addon command', function(c1, c2, ...)
    
end)
