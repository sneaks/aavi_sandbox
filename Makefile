install:
	sudo cp aavi_sandbox.sh /usr/local/bin/aavi_sandbox
	sudo cp aavi_tui.sh /usr/local/bin/aavi_sandbox_tui
	sudo chmod +x /usr/local/bin/aavi_sandbox
	sudo chmod +x /usr/local/bin/aavi_sandbox_tui

uninstall:
	sudo rm -f /usr/local/bin/aavi_sandbox
	sudo rm -f /usr/local/bin/aavi_sandbox_tui

test:
	./aavi_sandbox.sh --status

doc:
	@echo "Aavi Sandbox CLI"
	@echo "Default mount path: /opt/aavi_sandbox_test"
	@echo "Available commands:"
	@echo "  --play SNAPSHOT [--target PATH]     Start a sandbox session"
	@echo "  --commit SNAPSHOT                   Commit overlay changes"
	@echo "  --clear SNAPSHOT                    Delete snapshot data"
	@echo "  --exit                              Exit sandbox session"
	@echo "  --status                            Report current sandbox status"
	@echo "  --list                              List snapshots"
	@echo "  --remove SNAPSHOT                   Delete snapshot index"
	@echo "  --target PATH                       Optional override for mount location"

.PHONY: install uninstall