"""Checks the controller and Windows adapter in this build process only."""
import argparse, json, struct
from pathlib import Path
from build import ROOT, GAME, Lua, literal, lua_value, sha, source

def run(entities=None,ffi_reference=None):
    profile=json.loads((ROOT/'profile.json').read_text())
    cd=profile['cooldown'];assert cd['base_seconds']==70
    assert struct.unpack('<f',bytes.fromhex(cd['before']))[0]==140
    assert struct.unpack('<f',bytes.fromhex(cd['after']))[0]==70
    f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
    effective=f32(f32(cd['base_seconds']*cd['upgrade_multipliers'][0])*cd['upgrade_multipliers'][1])
    assert effective==cd['effective_seconds'] and round(effective)==cd['display_seconds']==60
    folder=ROOT/'build/test-fixtures';folder.mkdir(parents=True,exist_ok=True)
    raw=entities.read_bytes() if entities else None
    for i,t in enumerate(profile['tables'],1):
        fixture=folder/f'{i}.bin'
        if raw is not None:
            h=5381
            for char in t['name']+'Data':h=(h*33+ord(char))&0xffffffff
            marker=struct.pack('<I4sI',(h-5381)&0xffffffff,b'LDLD',1)
            assert raw.count(marker)==1
            start=raw.index(marker)+28;table=raw[start:start+t['size']]
        else:
            if not fixture.exists():
                raise FileNotFoundError('Supply --entities PATH/TO/generated_entities.dl_bin from your matching game extraction; fixtures are not distributed.')
            table=fixture.read_bytes()
        assert len(table)==t['size'] and sha(table)==t['sha256']
        fixture.write_bytes(table)
    outputs=[]
    for test in (ROOT/'tests/controller.lua',ROOT/'tests/install.lua'):
        lua=Lua(GAME/'bin/lua51.dll')
        try:
            prefix='ROOT='+literal(ROOT.as_posix().encode())+';FIXTURES='+literal(folder.as_posix().encode())+';PROFILE='+lua_value(profile)+';'
            result=lua.run(prefix+'return assert(loadfile('+literal(test.as_posix().encode())+'))()').decode()
            print(result);outputs.append(result)
        finally:lua.close()
    # Real WinAPI calls are restricted to our own process and allocated data.
    for first in ((True,False) if ffi_reference else (False,)):
        lua=Lua(GAME/'bin/lua51.dll')
        try:
            reference='local old=assert(loadfile('+literal(ffi_reference.resolve().as_posix().encode())+'))()()' if ffi_reference else ''
            eat='local api=assert(loadfile('+literal((ROOT/'src/windows.lua').as_posix().encode())+'))()()'
            code='\n'.join([reference,eat] if first else [eat,reference])+'''
                assert(api.sha('abc')=='BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD')
                local p=api.allocate('hello');assert(api.read(p,5)=='hello')
                api.write(p,'hello','world');assert(api.read(p,5)=='world')
                assert(not pcall(api.write,p,'hello','wrong') and api.read(p,5)=='world')
                local module=api.module('lua51.dll');assert(not api.writable(module,8))
                return api.module_hash(module)
            '''
            assert lua.run(code).decode()==sha((GAME/'bin/lua51.dll').read_bytes())
        finally:lua.close()
    outputs.append('PASS real Windows read/write preconditions, SHA256, module hash'+(', shared LuaJIT FFI in both addon load orders' if ffi_reference else ''))
    print(outputs[-1])
    lua=Lua(GAME/'bin/lua51.dll')
    try:assert lua.compile(source())[:5]==b'\x1bLJ\x02\x02'
    finally:lua.close()
    (ROOT/'build/test-report.json').write_text(json.dumps({'passed':outputs,'game_process_accessed':False},indent=2))
    return outputs

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--entities',type=Path,help='Locally extracted matching generated_entities.dl_bin; never committed')
    parser.add_argument('--ffi-reference',type=Path,help='Optional other addon Windows API factory for shared LuaJIT checks')
    args=parser.parse_args();run(args.entities,args.ffi_reference)
