Additional Resources
1. Elevate your permissions to root. Execute ./bootstrap.sh to complete the setup of the environment.
2. Edit prometheus-config-map.yml to create two service discovery targets.
3. Create a job called kubernetes-apiservers.
  - The role should be set to endpoint and the scheme should be set to https.
  - Configure tls_config to use /var/run/secrets/kubernetes.io/serviceaccount/ca.crt as the CA file, and /var/run/secrets/kubernetes.io/serviceaccount/token on the bearer token file.
  - Relabel __meta_kubernetes_namespace, __meta_kubernetes_service_name, and __meta_kubernetes_endpoint_port_name.
  - Make sure these source labels are kept, and set default, kubernetes, and https for the RegEx.
4. Create a second job called kubernetes-cadvisor.
  - Set the scheme to https.
  - Configure tls_config to use /var/run/secrets/kubernetes.io/serviceaccount/ca.crt as the CA file and /var/run/secrets/kubernetes.io/serviceaccount/token on the bearer token file.
  - Set the role to node.
  - Configure three relabel settings:
    - Create a labelmap that will remove __meta_kubernetes_node_label_ from the label name.
    - Create a target label that will replace the address with kubernetes.default.svc:443.
    - Finally, create a target label that will replace the metrics path with /api/v1/nodes/${1}/proxy/metrics/cadvisor and set the __meta_kubernetes_node_name source label as the value of ${1}.
5. Reload the Prometheus pod by deleting it.
6. Verify that two service discovery endpoints are appearing as targets.


######

Configure the Service Discovery Targets
Prepare the environment and create the monitoring namespace as below:

sudo su -
cd /root/prometheus
./bootstrap.sh
kubectl get pods -n monitoring
Edit prometheus-config-map.yml and add in the two service discovery targets:

vi prometheus-config-map.yml
When we're done, the whole file should look like this:

apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  prometheus.yml: |-
    global:
      scrape_interval: 5s
      evaluation_interval: 5s

    scrape_configs:
      - job_name: 'kubernetes-apiservers'

        kubernetes_sd_configs:
        - role: endpoints
        scheme: https

        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      - job_name: 'kubernetes-cadvisor'

        scheme: https

        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
        - role: node

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
          
Apply the Changes to the Prometheus Configuration Map
Now, apply the changes that were made to prometheus-config-map.yml:

kubectl apply -f prometheus-config-map.yml

Delete the Prometheus Pod

1. List the pods to find the name of the Prometheus pod:
kubectl get pods -n monitoring
2. Delete the Prometheus pod:
kubectl delete pods <POD_NAME> -n monitoring
3. Open up a new web browser tab, and navigate to the Expression browser. This will be at the public IP of the lab server, on port 8080:
http://<IP>:8080
4. Click on Status, and select Target from the dropdown. We should see two targets in there.


Once done with above steps, grab your piublic ip and port and paste it in the browser and you should see prometheus dashboard, go to Status -> Target to which will show the service discovery which we configured
Should be some something like the image is attached in the repo.

