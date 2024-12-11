sudo docker build --network=host \
--add-host registry.npmjs.org:104.16.1.35 \
--add-host codeload.github.com:140.82.121.9 \
--add-host googlechromelabs.github.io:185.199.108.133 \
--add-host deb.debian.org:151.101.134.132 \
--add-host pypi.org:151.101.1.223 \
--add-host files.pythonhosted.org:151.101.1.223 \
--add-host pypi.python.org:151.101.1.223 \
-f Dockerfile --force-rm -t custom_superset:0.1.0 .