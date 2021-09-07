#!/bin/bash
if [ $(whoami) = 'root' ]; then
# basics
apt-get install -y build-essential git lua5.1 lua5.1-dev openssl libssl-dev libsdl2-dev >/dev/null
# luarocks
git clone https://github.com/luarocks/luarocks.git luarock >/dev/null
cd luarock
./configure >/dev/null
make >/dev/null
make install >/dev/null
cd ..
rm -r luarock
luarocks install luasec >/dev/null
luarocks install http >/dev/null
luarocks install luasocket >/dev/null
luarocks install lua-cjson >/dev/null
luarocks install lua-sdl2 >/dev/null
luarocks install luasec --lua-version=5.1 >/dev/null
luarocks install http --lua-version=5.1 >/dev/null
luarocks install luasocket --lua-version=5.1 >/dev/null
luarocks install lua-cjson --lua-version=5.1 >/dev/null
luarocks install lua-sdl2 --lua-version=5.1 >/dev/null
# done
echo "Successfully Setup"
exit 0
else
echo "Setup script needs to be ran as root"
exit 1
fi
