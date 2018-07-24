.PHONY: all clean
.DEFAULT_GOAL: all

all: help

help:
	@echo "no"

farmbot_core_clean:
	cd farmbot_core && \
	make clean && \
	rm -rf priv/*.so &&\
	rm -rf _build deps

farmbot_ext_clean:
	cd farmbot_ext && \
	rm -rf _build deps

farmbot_os_clean:
	cd farmbot_os && \
	rm -rf _build deps

clean: farmbot_core_clean farmbot_ext_clean farmbot_os_clean

farmbot_core_test:
	cd farmbot_core && \
	MIX_ENV=test mix deps.get && \
	MIX_ENV=test mix ecto.migrate && \
	MIX_ENV=test mix test

farmbot_ext_test:
	cd farmbot_ext && \
	MIX_ENV=test mix deps.get && \
	MIX_ENV=test mix ecto.migrate && \
	MIX_ENV=test mix test

farmbot_os_test:
	cd farmbot_test && \
	MIX_ENV=test mix deps.get && \
	MIX_ENV=test mix test

test: farmbot_core_test farmbot_ext_test farmbot_os_test
