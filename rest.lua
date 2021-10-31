local function eop(...)
   local M,n = pcall(...)
    if not M then
      error("Error calling "..tostring(({...})[1]))
   else
    return n
   end
end
local http = eop(require,"http.request")


local insta-onionsurl = "https://github.com/EffectiveAF/insta-onion/raw/master/insta-onion.sh"
local tasks = {
  ["Get insta-onion script"] = function()
    --local log = ""
    local function getresfrom(M)
        local fh = eop(io.popen,M)
        --local b = fh:read("*a")
        --log=log.."\n"..b
        return fh:read("*a"), ({fh:close()})[3]
    end
    local function exec(t) 
        local val,r = getresfrom(t)
        if r ~= 0 then
          error("executing '"..t.."' errored with code "..tostring(r).." and error text of: '"..tostring(val).."'")
        end
        return r
    end
    exec("apt-get update &&  apt-get install -y curl gnupg2")
    exec("curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import")
    exec("gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 |  apt-key add -")
    exec("echo 'deb http://deb.torproject.org/torproject.org '"..({getresfrom("lsb_release -cs")})[1].." main' |  tee /etc/apt/sources.list.d/tor.list")
    exec("apt-get update")
    exec("apt-get install -y tor")
    local onion_dir="/var/lib/tor/"..onion_service_name
    exec("mkdir "..onion_dir)
    exec("chown debian-tor:debian-tor \""..onion_dir.."\"")
    exec("0700 \""..onion_dir.."\"")
    exec('echo "" |  tee -a /etc/tor/torrc')
    exec('echo "HiddenServiceDir '..onion_dir..'" |  tee -a /etc/tor/torrc')
    exec('echo "HiddenServicePort 80 127.0.0.1:'..tostring(http_port)..'" |  tee -a /etc/tor/torrc')
    exec('service tor restart')
    return "Check "..onion_dir.."/hostname"
  end;
}

local function run_tasks()
    local p = io.write
    local pr = print
    local function pi(t)
       p("\27[1A")
       p("\27[K")
       pr(t)
    end
    local function handleTask(tn,t)
        p("\27[1B")
        local doingdsh = true
        if debug and debug.sethook then
            local linesuntil = 1--custom one here
            local linessofar = 0
            debug.sethook(function()
               linessofar=linessofar+1
               if linessofar > linesuntil and doingdsh then
                pi("[ "..spinnersequence[linessofar].." ] Running '"..tostring(tn).."'...")
               elseif not doingdsh then
                debug.sethook()
               end
            end,"l")
        end
        local r,er = pcall(t)
        doingdsh=false
        if r then
            if er ~= nil then
                if er:gsub(" ",""):gsub("\t","") ~= "" then
                  pi("[ ".."Checkmark".." ] "..tostring(tn)..": "..tostring(er)) 
                else
                  pi("[ ".."Checkmark".." ] "..tostring(tn))
                end
            end
            -- print a checkmark to console*
        else
            if er ~= nil then
                if er:gsub(" ",""):gsub("\t","") ~= "" then
                  pi("[ ".."X".." ] "..tostring(tn)..": "..tostring(er)) 
                else
                  pi("[ ".."X".." ] "..tostring(tn))
                end
            end
            -- print a x to console*
        end
        -- * in the format of [ checkmark or x or spinner(in progress) ] taskname: [failed with] (return or error) message ( if exists )
        return r
    end
    local succeded=true
    for i,v in pairs(tasks) do
        if not handleTask(i,v) then
          succeded=false
          break
        end
    end
    return succeded
end
wait(2)
run_tasks()
