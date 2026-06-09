<div align="center">
	<p>
	<img alt="Thoughtworks Logo" src="https://raw.githubusercontent.com/twplatformlabs/static/master/psk_banner.png" width=800 />
	<h2>psk-platform-svc-simple-observability</h2>
	<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/github/license/twplatformlabs/psk-platform-svc-simple-observability"></a> <a href="https://aws.amazon.com"><img src="https://img.shields.io/badge/-deployed-blank.svg?style=social&logo=amazon"></a>
	</p>
</div>

Deploys a basic, cluster-local observability system. This is not a typical configuration for an engineering platform and is intended only to provide functionality for demonstrating the use of observability tools within sample application release lifecycles.  

The deployment assumes the psk crossplane capabilities are deployed.  

This configuration is single-tenant by design for demonstration purposes.  

obs-dependencies:  
* s3bucket and pvc for loki

obs-loki:
* loki receiver and grafana data traget for logs and events

opentelemetry-collectors:  
* otel-daemonset for logs, metrics, traces
* otel-deployment for events
