cd "~\Git\PSCommunity\Containers\PowerShell Universal Dashboard"

# Note: Remember to switch to Windows Containers before building the docker file (Linux is the default after installing Docker for Windows)
docker build WindowsServerCoreDemoWebsite -t psmag:demowebsite --no-cache
docker build NanoDemoWebsite -t psmag:nanodemowebsite --no-cache

#region 1 Windows Server Core
$ContainerID = docker run -d --rm psmag:demowebsite
$ContainerIP = docker inspect -f "{{ .NetworkSettings.Networks.nat.IPAddress }}" $ContainerID

# Verify that the website is up and running
Start-Process -FilePath iexplore.exe -ArgumentList http://$ContainerIP/register/123
Start-Process -FilePath chrome.exe -ArgumentList http://$ContainerIP/register/123

# Optionally, connect to a container instance interactively to inspect the environment.
# The IIS image have a service monitor as an entrypint, thus we need to override this to get into the container interactively
docker run --entrypoint=powershell -it psmag:demowebsite

docker stop $ContainerID

#endregion

#region 2 Nano Server 1709
$ContainerID = docker run -d --rm psmag:nanodemowebsite
$ContainerIP = docker inspect -f "{{ .NetworkSettings.Networks.nat.IPAddress }}" $ContainerID

# Verify that the website is up and running
Start-Process -FilePath iexplore.exe -ArgumentList http://$ContainerIP/register/123
Start-Process -FilePath chrome.exe -ArgumentList http://$ContainerIP/register/123

# Optionally, connect to the container instance interactively to inspect the environment
docker exec -ti $ContainerID powershell #pwsh/powershell

docker stop $ContainerID

#endregion