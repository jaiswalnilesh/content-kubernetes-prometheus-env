Additional Resources

1. Become root, then execute the /root/bootstrap.sh script to complete the setup of the environment.

2. Edit the Configuration Map prometheus-rules-config-map.yml, which is located in /root/prometheus.

 - Create a new file called process_rules.yml that will be managed by the configuration map.
 - Create a group called process_rules.
 - Create a rule called job:process_cpu_seconds:rate5m.
 - Use the rate function as the expression to calculate the process_cpu_seconds_total metric's per-second average rate of increase over a span of 5 minutes.
3. Apply the changes to process_rules.yml.

4. Now edit the ConfigMap prometheus-config-map.yml to include the rule files. The rules files section should include all rule files located in /var/prometheus/rules/ that end with _rules.yml without having to hard code the file.

5. Apply the changes to prometheus-config-map.yml.

6. Last of all, edit prometheus-deployment.yml. For your Prometheus container, add a new volume called prometheus-rules-volume that mounts /var/prometheus/rules.

 - In the volumes section, add a new volume called prometheus-rules-volume that maps to the prometheus-rules-conf Config Map.
7. Apply the changes to prometheus-deployment.yml.

### Consider a situation when expression query is running slow, After careful investigation you decided to convert this expression rules into recording rules, 
    In order to go ahead add the recording rules in prometheus environment, please follow below steps and apply recording rules

Create the Recording Rule

1. Add the job:process_cpu_seconds:rate5m recording rule to prometheus-rules-config-map.yml. The file should look like this when we're done editing it:
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: prometheus-rules-conf
  namespace: monitoring
data:
  process_rules.yml: |
    groups:
    - name: process_rules
      rules:
      - record: job:process_cpu_seconds:rate5m
        expr: (rate(process_cpu_seconds_total[5m]))
2. Apply the changes with this command:
kubectl apply -f prometheus-rules-config-map.yml

Update the Prometheus Configuration

1. Edit prometheus-config-map.yml
vi prometheus-config-map.yml
2. Add the rule files to prometheus-config-map.yml:
rule_files:
    - /var/prometheus/rules/*_rules.yml
3. It should look like this when we're done:

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

    rule_files:
    - /var/prometheus/rules/*_rules.yml
    
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

      - job_name: 'kubernetes-nodes'

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
          replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: 'kubernetes-pods'

        kubernetes_sd_configs:
        - role: pod

        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name

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

      - job_name: 'kubernetes-service-endpoints'

        kubernetes_sd_configs:
        - role: endpoints

        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name
4. Apply the changes with this command:
kubectl apply -f prometheus-config-map.yml


Add `prometheus-rules-conf` to the Prometheus Deployment

1. Edit prometheus-deployment.yml and add the prometheus-rules-volume volume to it. When we're finished, it should look like this:
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: monitoring
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: prometheus-server
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.2.1
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus/"
            - "--web.enable-lifecycle"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: prometheus-config-volume
              mountPath: /etc/prometheus/
            - name: prometheus-storage-volume
              mountPath: /prometheus/
            - name: prometheus-rules-volume
              mountPath: /var/prometheus/rules
      volumes:
        - name: prometheus-config-volume
          configMap:
            defaultMode: 420
            name: prometheus-server-conf

        - name: prometheus-rules-volume
          configMap:
            name: prometheus-rules-conf

        - name: prometheus-storage-volume
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9090'

spec:
  selector:
    app: prometheus-server
  type: NodePort
  ports:
    - port: 8080
      targetPort: 9090
      nodePort: 8080
2. Apply the changes with this command:
kubectl apply -f prometheus-deployment.yml
