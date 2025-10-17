git:
	@if [ -z "$(M)" ]; then echo 'ERROR: set M, e.g. make git M="feat: deploy function"'; exit 1; fi
	git add -A
	git commit -m "$(M)"
	git push origin main