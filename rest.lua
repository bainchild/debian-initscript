local __TESTING = false

local function wait(s)
        os.execute("sleep "..tostring(s))
end
local function eop(...)
   local M,n = pcall(...)
    if not M then
      error("Error calling "..tostring(({...})[1]))
   else
    return n
   end
end
local function getresfrom(M)
   if not __TESTING then
      local fh = eop(io.popen,M)
      --local b = fh:read("*a")
      --log=log.."\n"..b
      return fh:read("*a"), ({fh:close()})[1]
   else
      return "",0
   end
end
local function exec(t)
   local val,r = getresfrom(t)
   if not r then
     error("executing '"..t.."' errored with code "..tostring(r).." and error text of: '"..tostring(val).."'")
   end
   return r
end

local onion_service_name,http_port="testing",80

-- HAVE TASKS ON DIFFERENT LINES , PERCENT DONE IS BASED ON LINES
local tasks = {
   {"Check root permissions",function()
    if __TESTING then
        return "Skipped for testing"
    end
    local res,c = getresfrom("whoami")
    res=res:sub(1,#res-1)
    if not c then
        error("Running 'whoami' errored!")
    elseif res ~= "root" then
        error("Running as '"..res.."' , not root!")
    else
        return "Running as root..."
    end
  end};
  {"Get tor",function()
    if __TESTING then 
        return "Skipped for testing"
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
    if (({getresfrom("ls -1 '"..onion_dir.."' | grep hostname")})[1]):gsub("\t",""):gsub(" ",""):gsub("\n","") ~= "" or __TESTING then
        return "Onion url: "..({getresfrom("cat '"..onion_dir.."/hostname'")})[1]
    else
        return "Use 'cat \""..onion_dir.."/hostname\"' once tor is started to get the Onion url"
    end
  end};
  {"Make autostart script for tor",function()
        if __TESTING then return "Skipped for testing" end
        local m = io.open("/etc/systemd/system/torboot.service","w+")
        if not m then error("Error opening service file!") end
        m:write([[
[Unit]
Description=Run tor on boot
[Service]
Type=simple
ExecStart=/bin/tor
Restart=on-failure
RestartSec=10
KillMode=process
[Install]
WantedBy=multi-user.target]])
        m:close()
        return "Successfully wrote /etc/systemd/system/torboot.service"
  end};
}

local function run_tasks()
    local p = io.write
    local pr = print
    local check = "\27[32mCheckmark\27[0m"
    local x = "\27[31mX\27[0m"
    local function pi(t)
       p("\27[1A")
       p("\27[K")
       pr(t)
    end
    p("\27[1;33mStarting "..tostring(#tasks).." tasks...\27[0m\n")
    local function handleTask(tn,t)
        p("\n")
        local doingdsh = true
        if debug and debug.sethook and debug.getinfo then
            local linesuntil = 1--custom one here
            local linessofar = 0
            local reallinessofar = 0
            local spinnersequence_ = {
                "-";"/";"|";"\\";"-";"/";"|";"\\";"-"
            }
            local spinnersequence = {}
            for i,v in ipairs(spinnersequence_) do
                table.insert(spinnersequence,"\27[35m"..tostring(v).."\27[0m")
            end
            local function map(n,a1,a2,b1,b2)
                return (b1+((n-a1)*(b2-b1)/(a2-a1)))
            end
            local function limit(t,s)
                if t <= s then
                        return t 
                elseif t%s == 0 then 
                        return s
                else
                        return t%s
                end
            end
            local function clamp(n,min,max)
                if n <= max and n >= min then
                        return n
                elseif n < min then
                        return min
                elseif n > max then
                        return max
                end
            end
            local ginfo = debug.getinfo(t,"S")
            local ldef,lldef = ginfo["linedefined"],ginfo["lastlinedefined"]
            debug.sethook(function()
               linessofar=linessofar+1
               if linessofar > linesuntil and doingdsh then
                reallinessofar=reallinessofar+1
                pi("[ "..spinnersequence[limit(reallinessofar,#spinnersequence)].." ]["..tostring(clamp(map(ldef+(reallinessofar),ldef,lldef,0,10)-10,0,100)).."%] Running '"..tostring(tn).."'...")
               elseif not doingdsh then
                debug.sethook()
               end
            end,"l")
        else -- todo: add option if debug.sethook exists but not debug.getinfo
                pi("[ ".."?".." ][?%] Running '"..tostring(tn).."'...")
        end
        local r,er = pcall(t)
        doingdsh=false
        if r then
            if er ~= nil then
                if er:gsub(" ",""):gsub("\t",""):gsub("\n","") ~= "" then
                  pi("[ "..check.." ] "..tostring(tn)..": "..tostring(er)) 
                else
                  pi("[ "..check.." ] "..tostring(tn))
                end
            else
                pi("[ "..check.." ] "..tostring(tn))
            end
            -- print a checkmark to console*
        else
            if er ~= nil then
                if er:gsub(" ",""):gsub("\t",""):gsub("\n","") ~= "" then
                  pi("[ "..x.." ] "..tostring(tn)..": "..tostring(er)) 
                else
                  pi("[ "..x.." ] "..tostring(tn))
                end
            else
                pi("[ "..x.." ] "..tostring(tn))
            end
            -- print a x to console*
        end
        -- * in the format of [ checkmark or x or spinner(in progress) ] taskname: [failed with] (return or error) message ( if exists )
        return r
    end
    local succeded=true
    for i,v in ipairs(tasks) do
        if not handleTask(v[1],v[2]) then
          succeded=false
          break
        end
    end
    return succeded
end
if not run_tasks() then os.exit(1) end
