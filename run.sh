password=test@123
docker container stop $(docker ps -a -q)
docker container prune -f
docker network prune -f
docker network create --subnet=192.168.1.0/24 myNet;

#Populating the databases
docker run -dit --cpus=1 --net myNet --ip 192.168.1.6 --name=mysqlcontainerairline -e MYSQL_ROOT_PASSWORD=test@123 -d mysql/mysql-server:latest
sleep 10
docker exec -i mysqlcontainerairline mysql -u root -p$password < mySQLcommandsFile.txt

#Starting the service containers
docker container run --rm -it -v $(pwd):/home/ballerina -u $(id -u):$(id -u) -e JAVA_OPTS="-Duser.home=/home/ballerina" choreoipaas/choreo-ballerina:observability-improvements ballerina build --skip-tests travelAgent
docker build -t travelobs -f src/travelAgent/docker/Dockerfile ${PWD}
docker run -dit --cpus=1 --net myNet --ip 192.168.1.2 --name=ta1 -p 9298:9298 travelobs:latest;

docker container run --rm -it -v $(pwd):/home/ballerina -u $(id -u):$(id -u) -e JAVA_OPTS="-Duser.home=/home/ballerina" choreoipaas/choreo-ballerina:observability-improvements ballerina build --skip-tests mockingServiceAirline
docker build -t airlineobs -f src/mockingServiceAirline/docker/Dockerfile ${PWD}
docker run -dit --cpus=1 --net myNet --ip 192.168.1.3 --name=mk1 airlineobs:latest;