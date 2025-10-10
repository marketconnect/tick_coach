git:
	@if [ -z "$(MSG)" ]; then echo 'ERROR: set MSG, e.g. make git MSG="feat: deploy function"'; exit 1; fi
	git add -A
	git commit -m "$(MSG)"
	git push origin main