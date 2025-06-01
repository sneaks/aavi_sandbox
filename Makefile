install:
	sudo cp aavi_sandbox.sh /usr/local/bin/aavi_sandbox
	sudo chmod +x /usr/local/bin/aavi_sandbox

uninstall:
	sudo rm -f /usr/local/bin/aavi_sandbox

test:
	./aavi_sandbox.sh --status