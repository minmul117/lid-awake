.PHONY: build install run uninstall sudoers clean

build:
	./scripts/build.sh

install:
	./scripts/install.sh

run: build
	open build/LidAwake.app

uninstall:
	-pkill -x LidAwake
	rm -rf /Applications/LidAwake.app
	@if [ -f /etc/sudoers.d/lidawake ]; then sudo rm -f /etc/sudoers.d/lidawake; fi

sudoers:
	./scripts/setup-sudoers.sh

clean:
	rm -rf build
