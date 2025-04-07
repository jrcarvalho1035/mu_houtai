local luacheckfile = {}
-- luacheck: std min
local function tt_luacheck_write_read_globals(f, key, tbl, writeKey)
    if tbl == nil then
        print('tbl==nil key=' .. key)
        return
    end

    local read_globals = {}
    for k, v in pairs(tbl) do
        table.insert(read_globals, {k, v})
    end
    -- table.sort(read_globals, function(a, b)
    --     return a[1] < b[1]
    -- end)
    if not writeKey then
        f:write(key .. '={\n')
    end
    f:write('    fields={\n')
    for _, data in ipairs(read_globals) do
        local k = data[1]
        local v = data[2]
        if type(v) == 'table' then
            f:write('        ' .. k .. '={\n')
            tt_luacheck_write_read_globals(f, k, v, true)
            f:write('    }, -- ' .. k .. '\n')
        else
            f:write('        ' .. k .. '={},\n')
        end
    end
    f:write('    }, -- fields\n') -- fields
    if not writeKey then
        f:write('}, --' .. key .. '\n') -- LActor
    end
end

function luacheckfile.tt_luacheck_config()
    local filepath = 'D:/luacheck_config.lua'
    local f = io.open(filepath, "w")
    if f == nil then
        print('tt_luacheck_config f==nil')
        return
    end

    f:write('--luacheck: std min\n')
    f:write('std="lua51"\n\n')

    f:write('--luacheck: ignore\n')
    f:write('globals={\n')
    -- f:write('std={\n')

    -- 尽量保持字母顺序
    local globals = {
        'std',
        'ActivitysMgrImpl',
        'BaseTypes',
        'CommonFunc',
        'DbServerProto',
        'Equipment',
        'EventCallDispatcher',
        'GameStartEventList',
        'LocalDT',
        'MonAtkOtherDispather',
        'MonDamageDispatcher',
        'MonDieDispatcher',
        'NetMsgsHandleT',
        'MiscFunc',
        'MonAllKilledDispatcher',
        'printf',
        'ScriptEventHandle',
        'SubFuncT1',
        'SubFuncT2',
        'SubFuncT3',
        'SubFuncT4',
        'SubFuncT5',
        'SubFuncT6',
        'SubFuncT7',
        'SubFuncT8',
        'SubFuncT9',
        'SubFuncT10',
        'SystemHandlerDispatcher',
    }

    for k in pairs(_G) do
        table.insert(globals, k)
    end
    table.sort(globals)

    local read_globals_list = {
        LActor = 1,
        -- Item = 1,
        System = 1,
        -- LSmallTeam = 1,
        -- DataPack = 1,
        LDataPack = 1,
        -- TeamFun = 1,
        Fuben = 1,
    }

    for _, k in ipairs(globals) do
        if not read_globals_list[k] then
            f:write('    \'' .. k .. '\',\n')
        end
    end

    f:write('} -- globals\n\n')

    -- read_globals
    f:write('--luacheck: ignore\n')
    f:write('read_globals={\n')
    -- local write_read_globals = function(key, tbl)
    --     local read_globals = {}
    --     for k, v in pairs(tbl) do
    --         table.insert(read_globals, {k, v})
    --     end
    --     table.sort(read_globals, function(a, b)
    --         return a[1] < b[1]
    --     end)
    --     f:write(key .. '={\n')
    --     f:write('    fields={\n')
    --     for _, data in ipairs(read_globals) do
    --         local k = data[1]
    --         local v = data[2]
    --         if type(v) == 'table' then
    --             f:write('        ' .. k .. '={')
    --             write_read_globals(k, v)
    --             f:write('    }, -- ' .. k .. '\n')
    --         else
    --             f:write('        ' .. k .. '={},\n')
    --         end
    --     end
    --     f:write('    }, -- fields\n') -- fields
    --     f:write('}, --' .. key .. '\n') -- LActor
    -- end
    for key in pairs(read_globals_list) do
        tt_luacheck_write_read_globals(f, key, _G[key])
    end

    -- local skip = {
    --     serverroute = 1
    -- }

    -- module
    -- for key in pairs(package.loaded) do
    --     local tb = _G[key]
    --     if tb and type(tb) == 'table' then
    --         if not skip[key] then
    --             print('key=' .. key)
    --             tt_luacheck_write_read_globals(f, key, tb)
    --         end
    --     end
    -- end

    f:write('}\n\n') -- read_globals

    -- ignore table
    f:write([[ignore = {
    '631',
    '621',
    '614',
    '613',
    '612',
    '611',
    '542',
    '311',
    '211',
    '212',
    '213',
    -- '112',
    '111',
    'tt_.*',
    '_.*',
    'gm.*',
    'cale.*',
    'PROP_.*',
    'cpp.*',

    -- robot
    'RS_.*',
    'RE_.*',
}
]])


    f:close()

    print('tt_luacheck_config ok')
end

function luacheckfile.init()
    print('luacheckfile.init')
    luacheckfile.tt_luacheck_config()
end

return luacheckfile
