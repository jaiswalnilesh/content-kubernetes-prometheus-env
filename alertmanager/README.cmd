Additional Resources
1. Use prometheus-rules-config-map.yml to create a configuration map for the Redis alerting rules:
 - The file is located in /root/prometheus.
 - Under the data section, add a new file called redis-alerts.yml.
 - Create an alerting group called redis_alerts.
 - This group will contain two rules: RedisServerGone and RedisServerDown.
2. The RedisServerDown alert:
 - The expression uses the redis_up metric and is filtered using the label app with media-redis as the value. The condition will equal 0.
 - The alert will fire if the condition remains true for 10 minutes.
 - The alert has a severity of critical.
 - Add a summary in annotations that says “Redis Server <SERVER_NAME> is down!”
 - Replace <SERVER_NAME> with the templating syntax that displays the instance label.
3. The RedisServerGone alert:
 - For the expression, use the absent function to evaluate the redis_up metric. Filter using the app label with a value of media-redis.
 - The alert will fire if the condition remains true for 1 minute.
 - The alert has a severity of critical.
 - Add a summary in annotations that says “No Redis servers are reporting!”
4. Apply the changes made in prometheus-rules-config-map.yml.
 - Make sure the rules propagate into Prometheus.
 - Delete the Prometheus pod to make the rules propagate.
 - Verify the rules are showing up by clicking on Alerts.
 
 
Create a ConfigMap That Will Be Used to Manage the Alerting Rules
Edit prometheus-rules-config-map.yml and add the Redis alerting rules. It should look like this when we're done:

apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: prometheus-rules-conf
  namespace: monitoring
data:
  redis_rules.yml: |
    groups:
    - name: redis_rules
      rules:
      - record: redis:command_call_duration_seconds_count:rate2m
        expr: sum(irate(redis_command_call_duration_seconds_count[2m])) by (cmd, environment)
      - record: redis:total_requests:rate2m
        expr: rate(redis_commands_processed_total[2m])
  redis_alerts.yml: |
    groups:
    - name: redis_alerts
      rules:
      - alert: RedisServerDown
        expr: redis_up{app="media-redis"} == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: Redis Server {{ $labels.instance }} is down!
      - alert: RedisServerGone
        expr:  absent(redis_up{app="media-redis"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: No Redis servers are reporting!

Apply the Changes Made to `prometheus-rules-config-map.yml`
Now, apply the changes that were made to prometheus-rules-config-map.yml:

kubectl apply -f prometheus-rules-config-map.yml


Delete the Prometheus Pod
1. List the pods to find the name of the Prometheus pod:
kubectl get pods -n monitoring
2. Delete the Prometheus pod:
kubectl delete pods <POD_NAME> -n monitoring
3. In a new browser tab, navigate to the Expression browser:
http://<IP>:8080
4. Click on the Alerts link to verify that the two Redis alerts are showing as green.
