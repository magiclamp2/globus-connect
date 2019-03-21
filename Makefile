include local.mk

YAMLPROTOTYPES = globus-connect-service.yaml.in  globus-connect-volume.yaml.in   globus-connect.yaml.in

SEDSPEC = \
-e "s/@NAMESPACE@/$(NAMESPACE)/"  \
-e "s%@REGISTRY@%$(REGISTRY)%"  \
-e "s/@NW@/$(NW)/" \
-e "s/@SIZE@/$(SIZE)/"  

YAMLFILES=$(subst .in,,$(YAMLPROTOTYPES))

default: $(YAMLFILES)

yaml: $(YAMLFILES)

$(YAMLFILES):
	sed $(SEDSPEC) $@.in > $@

IMAGE = globus-personal-connect

image: yaml
	docker build -t $(IMAGE) . 
	docker tag $(IMAGE) $(REGISTRY)/$(IMAGE)
	docker push $(REGISTRY)/$(IMAGE):latest

clean:
	- /bin/rm $(YAMLFILES)

