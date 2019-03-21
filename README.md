## GridFTP server /Globus Connect container

### Build docker image

Edit local.mk file  and set your local variables: NAMESPACE, SIZE,NW 


``` bash
make image
```

### Testing image
```
docker run -i -t --rm globus-connect bash
```

### Security
make sure the following ports are allowed by the base host:
* GridFTP: 2811, 50000-51000 
* bwctl: 4823, 5001-5900, 6001-6200
* owamp: 861, 8760-9960

### Build a Globus Connect container with kubernetes

#### Update local.mk file

Edit local.mk file and Make sure the variables are per your local installation.
If you are instantiating a container on PRP K8S cluster the only variables
that need an update are :

* SIZE - volume size (in Gb) to use for mounting on a container, default is 50G
* NAMESPACE - change to your own namespace 

The remaining variables are :

* REGISTRY - PRP default docker images registry, default is "gitlab-registry.nautilus.optiputer.net/prp/globus-connect"
* NW - physical node network speed, default is 40G

If your kubernetes setup does not have nodes connected on 40Gb network or the
node selection is done differently, you will need to modify the portion of
the  globus-connect.yaml.in file according to your settings:
```bash
nodeSelector:
  nw: @NW@G
```
and update  SEDSPEC definition in Makefile per your change.


#### Create yaml files from templates 

``` bash
make yaml
```

This command creates yaml files needed for kubernetes commands from the templates

#### Create service, volume and a container 

Use your namespace in the commands below to start service, volume and a container:

``` bash
kubectl create -f globus-connect-service.yaml -n YourNS
kubectl create -f globus-connect-volume.yaml YourNS
kubectl create -f globus-connect.yaml YourNS
```

Check if the container is running:

```bash
kubectl get pods -n YourNS
```

When the status of the pod is "Running" can connect to the pod  as a superuser:

``` bash
kubectl exec -it globus-connect-0 -n YourNS bash
```


### Using Globus Connect Personal on a container

The docker file is updated with globusconnectpersonal tools. 
Once the container is up and running  follow these steps to create and
configure Globus personal endpoint (Globus login account is needed).
This will allow a user to use the Globus web application https://www.globus.org/app/transfer
to transfer files to/from a container Globus endpoint to another Globus endpoint.

After connecting to the pod can run the following steps :

#### 1 Become a gridftp user
```bash
su - gridftp
```
#### 2 Login to your Globus account
``` bash
$ globus login --no-local-server
```
You will see the output similar to the following :
``` text
Please authenticate with Globus here:
------------------------------------
https://auth.globus.org/v2/oauth2/authorize?prompt=login&access_type=offline&state=_default&redirect_uri=https
%3A%2F%2Fauth.globus.org%2Fv2%2Fweb%2Fauth-code&response_type=code&client_id=85...
&scope=openid+profile+email+uuview_identity_set+urn%3Aglobus%3Aauth%3Ascope%3Atransfer.api.globus.org%3Aall
------------------------------------
Enter the resulting Authorization Code here:
```
At this point the prompt is waiting for the authorization code. 
Paste the URL from the output into a web browser (not on a container) and follow the directions
to login using CILogon. You may use your Globus account or your institutional
account that is recognized by Globus.  Once you login you will be given
and authorization code string which you need to paste at the prompt on a
container.  If successful, the results is:
``` text
You have successfully logged in to the Globus CLI as YouCredential@your.org
```

The authentication string given by Globus  in a web browser is valid for ~10 min.

#### 3 Create a Globus endpoint

Use a unique name for the endpoint, in the command below it is "myep"
``` bash
$ globus endpoint create --personal myep | tee endpoint-info
Endpoint created successfully
Endpoint ID: 087ecee8-d7cd-11e8-8c7b-0a1d4c5c
Setup Key: 93229f51-7c87-4041-829e-7a644ac8
```
Save the Endpoint as variables for the next commands

``` bash
ep=087ecee8-d7cd-11e8-8c7b-0a1d4c5c
epkey=93229f51-7c87-4041-829e-7a644ac8
```

#### 4 Generate a setup key for the endpoint and create endpoint

``` bash
$ cd globusconnectpersonal-2.3.6/
$ ./globusconnectpersonal -setup $epkey
Configuration directory: /home/gridftp/.globusonline/lta
Contacting relay.globusonline.org:2223
Done!
```

#### 5 Verify Endpoint is configured

``` bash
$ globus endpoint search --filter-scope my-endpoints
ID                | Owner                  | Display Name 
------------------| -----------------------| -------------
087ecee8-d7cd-... | YouCredential@your.org | myep
85f00dd8-8228-... | YouCredential@your.org | test-globus-connect
```
A user can have multiple endpoints and they all will be listed.

#### 6 Start personal Globus connect

``` bash
$ ./globusconnectpersonal -start &
```

At this point configure personal endpoint shows in the Globus  web application
and one can use it for transferring  the files to/from other endpoints.

NOTE: one need to have a paid-for Globus account in order to transfer files
between two personal endpoints. For a base Globus account one can  have
multiple  personal endpoints and use them for transfers to/from other (public
or per login) endpoints.

#### 7 Saving endpoint info

When container restarts your Globus setup is gone but the endpoint info in the
Globus web app remains. One can save endpoint setup in a persistent volume
that was used for the container, for example /data. These commands are
executed as a superuser:

``` bash
# mkdir /data/gridftp-save; 
# chown gridftp.gridftp /data/gridftp-save
# cd ~gridftp/
# cp -p -r .globus* /data/gridftp-save/
# cp -p endpoint-info /data/gridftp-save/

```
After a container restart will need to restore the saved info
in order to reuse the endpoint (commands assume gridftp user):

``` bash
$ cp -p -r /data/gridftp-save/.glob* ~ 
$ cp -p  /data/gridftp-save/endpoint-info ~
```
