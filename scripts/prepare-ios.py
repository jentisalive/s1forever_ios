"""Apply narrow, checked patches to a pinned engine; stage the bundled mod."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[1]
engine = root / '.build-deps/engine'
def replace(path, old, new, count=None):
    p = engine / path
    s = p.read_text()
    if old not in s:
        if new in s:
            return
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
replace('RSDKv4/main.cpp', '    SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON', '#if RETRO_PLATFORM == RETRO_iOS\n    if (!IOSPrepareGame()) return 1;\n    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");\n    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");\n#endif\n    SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON', 1)
# chdir(Documents) makes existing relative resource/settings/mod paths writable.
# Existing iOS save branches use this stable bridge function.
stage = root / 'build-resources'
if stage.exists(): shutil.rmtree(stage)
(stage / 'mods').mkdir(parents=True)
shutil.copytree(root / 'Mods/Sonic 1 Forever', stage / 'mods/Sonic 1 Forever')
p = stage / 'mods/Sonic 1 Forever/Scripts/Title/Sega.txt'
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
