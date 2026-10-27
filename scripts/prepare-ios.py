"""Apply narrow, checked patches to a pinned engine; stage the bundled mod."""
from pathlib import Path
import shutil
import json
import re
root = Path(__file__).resolve().parents[1]
engine = root / '.build-deps/engine'
def replace(path, old, new, count=None):
    p = engine / path
    s = p.read_text()
    if new in s:
        return
    if old not in s:
        raise RuntimeError(f'Upstream context changed: {path}: {old[:70]}')
    if count is not None and s.count(old) != count:
        raise RuntimeError(f'Unexpected match count in {path}')
    p.write_text(s.replace(old, new))
h = 'RSDKv4/RetroEngine.hpp'
replace(h, '#if __IPHONEOS__', '#include <TargetConditionals.h>\n#if TARGET_OS_IPHONE', 1)
replace(h, '|| RETRO_PLATFORM == RETRO_ANDROID\n#ifdef RETRO_USE_SDL2', '|| RETRO_PLATFORM == RETRO_ANDROID || RETRO_PLATFORM == RETRO_iOS\n#ifdef RETRO_USE_SDL2', 1)
# iOS uses the same GLES 1 fixed-function backend as Android.
replace(h, '#if RETRO_PLATFORM == RETRO_ANDROID\n#define GL_GLEXT_PROTOTYPES', '#if RETRO_PLATFORM == RETRO_ANDROID || RETRO_PLATFORM == RETRO_iOS\n#define GL_GLEXT_PROTOTYPES', 1)
replace(h, '#include <GLES/gl.h>\n#include <GLES/glext.h>', '#if RETRO_PLATFORM == RETRO_iOS\n#include <OpenGLES/ES1/gl.h>\n#include <OpenGLES/ES1/glext.h>\n#else\n#include <GLES/gl.h>\n#include <GLES/glext.h>\n#endif', 1)
replace(h, '|| RETRO_PLATFORM == RETRO_ANDROID || RETRO_PLATFORM == RETRO_LINUX\n#if RETRO_USING_SDL2', '|| RETRO_PLATFORM == RETRO_ANDROID || RETRO_PLATFORM == RETRO_LINUX || RETRO_PLATFORM == RETRO_iOS\n#if RETRO_USING_SDL2', 1)
replace(h, '#include <vorbis/vorbisfile.h>\n#elif RETRO_PLATFORM == RETRO_OSX', '#include <vorbis/vorbisfile.h>\n#if RETRO_PLATFORM == RETRO_iOS\nconst char *getDocumentsPath();\nbool IOSPrepareGame();\n#endif\n#elif RETRO_PLATFORM == RETRO_OSX', 1)
d = 'RSDKv4/Drawing.cpp'
replace(d, '#if RETRO_PLATFORM != RETRO_ANDROID', '#if RETRO_PLATFORM != RETRO_ANDROID && RETRO_PLATFORM != RETRO_iOS')
# Keep Android-only audio code untouched, share only graphics dimensions.
replace(d, '#if RETRO_PLATFORM == RETRO_ANDROID\n    Engine.', '#if RETRO_PLATFORM == RETRO_ANDROID || RETRO_PLATFORM == RETRO_iOS\n    Engine.')
# UIKit owns a non-zero framebuffer; retain it across high-resolution setup.
replace(d, 'void SetupViewport()\n{', 'void SetupViewport()\n{\n#if RETRO_PLATFORM == RETRO_iOS && RETRO_USING_OPENGL\n    GLint iosFramebuffer = 0;\n    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &iosFramebuffer);\n#endif', 1)
replace(d, '        glBindFramebuffer(GL_FRAMEBUFFER, 0);', '#if RETRO_PLATFORM == RETRO_iOS\n        glBindFramebuffer(GL_FRAMEBUFFER, iosFramebuffer);\n#else\n        glBindFramebuffer(GL_FRAMEBUFFER, 0);\n#endif')
# SDL's display mode uses logical points; the GLES viewport needs drawable pixels.
replace(d, '        int w = mode.w;\n        int h = mode.h;', '        int w = mode.w;\n        int h = mode.h;\n#if RETRO_PLATFORM == RETRO_iOS\n        SDL_GL_GetDrawableSize(Engine.window, &w, &h);\n#endif', 1)
replace(d, '        if (mode.h > mode.w) {', '        if (h > w) {', 1)
replace('RSDKv4/main.cpp', '    SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON', '#if RETRO_PLATFORM == RETRO_iOS\n    if (!IOSPrepareGame()) return 1;\n    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");\n    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");\n#endif\n    SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON', 1)
# Forever's legacy compiler exposed a larger common alias vocabulary. Keep the
# current drawing FX values, but add the missing priority/input/collision names.
# Values were checked against the shipped Forever engine and current enum headers.
aliases = json.loads((root / 'scripts/forever-aliases.json').read_text())
script = 'RSDKv4/Script.cpp'
# Forever's longest function names exceed the upstream 31-character limit.
# Match the compiler's 64-byte declaration buffer, including the terminator.
replace('RSDKv4/Script.hpp', '    char name[0x20];', '    char name[0x40];', 1)
replace(script, '#define COMMON_SCRIPT_VAR_COUNT (34)', f'#define COMMON_SCRIPT_VAR_COUNT ({34 + len(aliases)})', 1)
replace(script, '#define COMMON_SCRIPT_VAR_COUNT (33)', f'#define COMMON_SCRIPT_VAR_COUNT ({33 + len(aliases)})', 1)
end_aliases = '    ScriptVariableInfo(VAR_ALIAS, ACCESS_PUBLIC, "DEVICE_ANDROID", "5"),\n};'
extra_aliases = ''.join(f'    ScriptVariableInfo(VAR_ALIAS, ACCESS_PUBLIC, "{name}", "{value}"),\n' for name, value in aliases.items())
replace(script, end_aliases, end_aliases[:-2] + extra_aliases + '};', 1)
# Forever calls the solid collision mode C_BOX; the current compiler names it
# C_SOLID. Its automatic-hitbox sentinel is separately declared as HITBOX_AUTO.
replace(script, 'ScriptVariableInfo(VAR_ALIAS, ACCESS_PUBLIC, "C_BOX", "65536")', 'ScriptVariableInfo(VAR_ALIAS, ACCESS_PUBLIC, "C_BOX", "1")', 1)
# Forever queries these native callbacks while initializing its options object.
# Without registration the saved function index defaults to SetAchievement (0).
legacy_fps_callbacks = """RetroEngine Engine = RetroEngine();

static void ForeverGetFrameRate() { scriptEng.checkResult = Engine.refreshRate; }
static void ForeverSetFrameRate(int *rate, int *unused)
{
    if (!rate || *rate < 30 || *rate > 240) return;
    Engine.refreshRate = *rate;
    scriptEng.checkResult = Engine.refreshRate;
}
"""
replace('RSDKv4/RetroEngine.cpp', 'RetroEngine Engine = RetroEngine();', legacy_fps_callbacks, 1)
replace('RSDKv4/RetroEngine.cpp', '    AddNativeFunction("GetWindowScale", GetWindowScale);', '    AddNativeFunction("GetFrameRate", ForeverGetFrameRate);\n    AddNativeFunction("SetFrameRate", ForeverSetFrameRate);\n    AddNativeFunction("GetWindowScale", GetWindowScale);', 1)
# chdir(Documents) makes existing relative resource/settings/mod paths writable.
# Existing iOS save branches use this stable bridge function.
stage = root / 'build-resources'
if stage.exists(): shutil.rmtree(stage)
(stage / 'mods').mkdir(parents=True)
mod_root = stage / 'mods/Sonic 1 Forever'
shutil.copytree(root / 'Mods/Sonic 1 Forever', mod_root)
# Current RSDKv4 indexes mod files only below Data/ and Bytecode/. The Forever
# distribution uses a legacy top-level Scripts/ directory; stage it where the
# engine's Data/Scripts requests can resolve it through the mod file map.
shutil.move(str(mod_root / 'Scripts'), str(mod_root / 'Data/Scripts'))
# Legacy Forever opcode spellings map to the current engine's equivalent
# operations; do this in staged text instead of changing bytecode opcode IDs.
legacy_calls = {'SetClassicFade': 'SetScreenFade', 'ClassicTint': 'DrawRect',
                'WriteSaveRam': 'WriteSaveRAM', 'Callfunction': 'CallFunction'}
call_pattern = re.compile(r'\b(' + '|'.join(legacy_calls) + r')(?=\s*\()')
for script_file in (mod_root / 'Data/Scripts').rglob('*.txt'):
    text = script_file.read_text()
    text = re.sub(r'\bengine\.platformID\b', 'RETRO_iOS', text)
    text = call_pattern.sub(lambda match: legacy_calls[match[0]], text)
    text = re.sub(r'(?m)^([ \t]*)function[ \t]+', r'\1public function ', text)
    text = re.sub(r'\bevent[ \t]+ObjectMain\b', 'event ObjectUpdate', text, flags=re.IGNORECASE)
    text = re.sub(r'\binput(Down|Press)\b', lambda match: 'key' + match[1], text)
    text = re.sub(r'\b(keyDown|keyPress)\.(Up|Down|Left|Right)\b', lambda match: match[1] + '.' + match[2].lower(), text)
    script_file.write_text(text)
p = mod_root / 'Data/Scripts/Title/Sega.txt'
s = p.read_text()
s = s.replace('\tReadSaveRAM()', '\tReadSaveRAM()\n\tsaveRAM[295] = 1')
p.write_text(s)
(stage / 'mods/modconfig.ini').write_text('[mods]\nSonic 1 Forever=true\n')
(stage / 'settings.ini').write_text('''[Dev]
DevMenu=false
EngineDebugMode=true
DataFile=Data.rsdk
TxtScripts=true
SkipStartMenu=true
[Window]
FullScreen=true
VSync=true
ScalingMode=0
[Game]
Language=0
''')
# Preserve upstream license and dependency notices in the bundle.
notice = stage / 'Notices'
notice.mkdir()
shutil.copyfile(root / 'README.md', notice / 'Forever.txt')
for dep, candidates in [('engine', ['LICENSE.md', 'LICENSE']), ('SDL2', ['LICENSE.txt']), ('ogg', ['COPYING']), ('vorbis', ['COPYING'])]:
    for name in candidates:
        src = root / '.build-deps' / dep / name
        if src.exists():
            shutil.copyfile(src, notice / f'{dep}.txt')
            break
print('Prepared iOS engine and Forever resources')
