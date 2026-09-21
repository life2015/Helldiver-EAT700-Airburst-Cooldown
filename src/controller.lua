-- Transactional replacement of two shared configuration tables.
return function(api,profile,base,state,cooldown_factory)
    local owned={}
    local owner
    local cooldown=profile.cooldown and cooldown_factory(api,profile.cooldown,base)
    local function bytes(hex)return(hex:gsub('..',function(s)return string.char(tonumber(s,16))end))end
    local function restore()
        local success=true
        if cooldown then
            local ok,restored=pcall(cooldown.restore)
            success=ok and restored
        end
        if #owned==0 then return success end
        if api.ptr(base+profile.owner_rva)~=owner then return false end
        for i=#owned,1,-1 do
            local t=owned[i]
            local current=api.ptr(t.slot)
            if current==t.copy then
                local ok=pcall(api.write,t.slot,api.pointer_bytes(t.copy),api.pointer_bytes(t.original))
                success=ok and success
            elseif current~=t.original then success=false end
        end
        return success
    end
    local function poll()
        local current_owner=api.ptr(base+profile.owner_rva)
        if #owned>0 then
            assert(current_owner==owner,'Table owner changed; restart required')
            for _,t in ipairs(owned)do assert(api.ptr(t.slot)==t.copy,'Another modification replaced a table pointer')end
            if cooldown then cooldown.check()end
            return
        end
        if not current_owner then state.status='waiting_for_tables';return end
        local prepared={}
        for _,t in ipairs(profile.tables)do
            local slot=current_owner+t.owner_offset
            local original=api.ptr(slot)
            if not original then state.status='waiting_for_tables';return end
            local raw=assert(api.read(original,t.size),'Table read failed')
            assert(api.sha(raw)==t.sha256,'Original table mismatch: '..t.name)
            local patched=raw
            for _,edit in ipairs(t.edits)do
                local before,after=bytes(edit.before),bytes(edit.after)
                assert(#before==4 and #after==4 and edit.offset>=0 and edit.offset+4<=#raw)
                assert(raw:sub(edit.offset+1,edit.offset+4)==before,'Original field mismatch')
                patched=patched:sub(1,edit.offset)..after..patched:sub(edit.offset+5)
            end
            assert(api.sha(patched)==t.patched_sha256,'Patched table mismatch')
            assert(api.writable(slot,8),'Table pointer is not private RW data')
            prepared[#prepared+1]={slot=slot,original=original,raw=raw,patched=patched,name=t.name}
        end
        if cooldown and not cooldown.prepare()then state.status='waiting_for_stratagem';return end
        owner=current_owner
        for _,t in ipairs(prepared)do
            t.copy=api.allocate(t.patched)
            owned[#owned+1]=t
        end
        -- All table validation and allocations precede the first pointer change.
        assert(api.ptr(base+profile.owner_rva)==owner,'Table owner changed during preparation')
        for _,t in ipairs(owned)do
            assert(api.ptr(t.slot)==t.original and api.read(t.original,#t.raw)==t.raw,'Table changed during preparation')
        end
        for _,t in ipairs(owned)do api.write(t.slot,api.pointer_bytes(t.original),api.pointer_bytes(t.copy))end
        if cooldown then cooldown.apply()end
        for _,t in ipairs(owned)do assert(api.ptr(t.slot)==t.copy,'Pointer replacement failed')end
        state.status='active';state.tables=2
        state.base_cooldown=profile.cooldown and profile.cooldown.base_seconds
        state.effective_cooldown=profile.cooldown and profile.cooldown.effective_seconds
    end
    return {poll=poll,restore=restore}
end
