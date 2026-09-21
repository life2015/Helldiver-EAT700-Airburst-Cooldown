local real=(assert(loadfile(ROOT..'/src/windows.lua')))()()
local controller=(assert(loadfile(ROOT..'/src/controller.lua')))()
local cooldown=(assert(loadfile(ROOT..'/src/cooldown.lua')))()
local function fixture()
    local memory={};local api={writes=0,allocations=0};local base,owner=0x100000,0x400000
    api.pointer_bytes=real.pointer_bytes;api.sha=real.sha
    local function set(p,data)memory[p]=data end
    function api.read(p,n)
        for start,data in pairs(memory)do
            if p>=start and p+n<=start+#data then return data:sub(p-start+1,p-start+n)end
        end
    end
    function api.ptr(p)
        local data=api.read(p,8);if not data then return nil end
        local n=0;for i=8,1,-1 do n=n*256+data:byte(i)end
        if n==0 then return nil end
        return n
    end
    function api.writable()return true end
    function api.write(p,expected,data)
        assert(api.read(p,#data)==expected);api.writes=api.writes+1
        set(p,data)
        if api.fail==p then api.fail=nil;error('injected write/readback failure')end
    end
    function api.allocate(data)
        api.allocations=api.allocations+1
        local p=0x20000000+api.allocations*0x200000;set(p,data);return p
    end
    set(base+PROFILE.owner_rva,real.pointer_bytes(owner))
    local originals={}
    for i,t in ipairs(PROFILE.tables)do
        local f=assert(io.open(FIXTURES..'/'..i..'.bin','rb'));local data=f:read('*a');f:close()
        assert(#data==t.size and real.sha(data)==t.sha256)
        local p=0x10000000+i*0x200000;set(p,data);originals[i]=p
        set(owner+t.owner_offset,real.pointer_bytes(p))
    end
    local cd=PROFILE.cooldown
    local function bytes(s)return(s:gsub('..',function(h)return string.char(tonumber(h,16))end))end
    local cdrecord=0x60000000;local cdname=0x61000000
    set(base+cd.slot_rva,real.pointer_bytes(cdrecord))
    set(cdrecord,bytes(cd.identity_hex))
    set(cdrecord+cd.name_offset,real.pointer_bytes(cdname))
    set(cdname,cd.name..'\0')
    set(cdrecord+cd.offset,bytes(cd.before))
    local state={};local control=controller(api,PROFILE,base,state,cooldown)
    return {api=api,set=set,memory=memory,base=base,owner=owner,originals=originals,state=state,control=control}
end
local t=fixture();t.control.poll()
assert(t.state.status=='active' and t.api.writes==3 and t.api.allocations==2)
for i,p in ipairs(PROFILE.tables)do
    local copy=t.api.ptr(t.owner+p.owner_offset)
    assert(copy~=t.originals[i] and real.sha(t.api.read(copy,p.size))==p.patched_sha256)
    assert(real.sha(t.api.read(t.originals[i],p.size))==p.sha256)
    local before,after=t.api.read(t.originals[i],p.size),t.api.read(copy,p.size)
    for offset=0,p.size-1 do
        local allowed=false
        for _,e in ipairs(p.edits)do if offset>=e.offset and offset<e.offset+4 then allowed=true end end
        assert(allowed or before:byte(offset+1)==after:byte(offset+1),'Unrelated configuration changed')
    end
end
t.control.poll();assert(t.api.writes==3 and t.api.allocations==2,'Repeated poll reallocated')
assert(t.control.restore())
for i,p in ipairs(PROFILE.tables)do assert(t.api.ptr(t.owner+p.owner_offset)==t.originals[i])end
local allocated=t.api.allocations;assert(t.control.restore() and t.api.allocations==allocated)

t=fixture();t.set(t.owner+PROFILE.tables[2].owner_offset,string.rep('\0',8))
t.control.poll();assert(t.state.status=='waiting_for_tables' and t.api.writes==0 and t.api.allocations==0)

t=fixture();local p=PROFILE.tables[1]
local raw=t.api.read(t.originals[1],p.size)
t.set(t.originals[1],string.char((raw:byte(1)+1)%256)..raw:sub(2))
assert(not pcall(t.control.poll));assert(t.api.writes==0 and t.api.allocations==0)

t=fixture();t.api.fail=t.owner+PROFILE.tables[2].owner_offset
assert(not pcall(t.control.poll));assert(t.control.restore())
for i,p in ipairs(PROFILE.tables)do assert(t.api.ptr(t.owner+p.owner_offset)==t.originals[i])end

t=fixture();t.control.poll();local foreign=0x70000000
t.set(t.owner+PROFILE.tables[2].owner_offset,real.pointer_bytes(foreign))
assert(not pcall(t.control.poll));assert(not t.control.restore())
assert(t.api.ptr(t.owner+PROFILE.tables[2].owner_offset)==foreign)
assert(t.api.ptr(t.owner+PROFILE.tables[1].owner_offset)==t.originals[1])

t=fixture();t.control.poll();local writes=t.api.writes
t.set(t.base+PROFILE.owner_rva,real.pointer_bytes(0x90000000))
assert(not pcall(t.control.poll));assert(not t.control.restore() and t.api.writes==writes+1)
-- A failure after the cooldown write rolls the whole transaction back.
t=fixture();t.api.fail=0x60000000+PROFILE.cooldown.offset
assert(not pcall(t.control.poll));assert(t.control.restore())
for i,p in ipairs(PROFILE.tables)do assert(t.api.ptr(t.owner+p.owner_offset)==t.originals[i])end
-- Never restore a same-valued pre-existing cooldown owned by another addon.
t=fixture()
local function bytes(s)return(s:gsub('..',function(h)return string.char(tonumber(h,16))end))end
t.set(0x60000000+PROFILE.cooldown.offset,bytes(PROFILE.cooldown.after))
assert(not pcall(t.control.poll));assert(t.control.restore() and t.api.writes==0)
return 'PASS real table replacements, EAT-17 unchanged, cooldown transaction, missing data, checksum refusal, rollback, foreign pointer, owner change'
