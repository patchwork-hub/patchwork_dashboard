# Patchwork Dashboard — Docker Swarm Lab

A reproducible container deployment lab demonstrating Docker Swarm
orchestration, rolling updates, rollback, and worker recovery.

Built on the upstream Patchwork Dashboard application, this fork adds
Vagrant infrastructure, Swarm deployment scripts, and an optional
database-free dashboard showing actual HTTP probe results.

**Author:** [silvaarohit](https://github.com/silvaarohit)  
**Upstream application:** [Patchwork Dashboard](https://github.com/patchwork-hub/patchwork_dashboard)  
**Container image:** [silvaarohit/patchwork_dashboard](https://hub.docker.com/r/silvaarohit/patchwork_dashboard)

> This is an infrastructure proof of concept, not a production deployment.
> The demo does not validate PostgreSQL, Redis, authentication, or Mastodon
> integration.

## Project overview

This project explores the complete delivery path from a container registry
to a running multi-node service:

1. Provision Ubuntu VMs with Vagrant and VirtualBox.
2. Install Docker Engine automatically.
3. Create a Swarm with one manager and two workers.
4. Deploy a prebuilt application image from Docker Hub.
5. Observe HTTP responses and serving-task identity.
6. Perform rolling configuration updates and rollback.
7. Observe recovery when a worker becomes unavailable.

The default setup uses a prebuilt image. You do not need to install Ruby,
Bundler, or application build tools to run the demonstration.

## My contributions

The upstream Rails application belongs to its original contributors.
My work in this fork focuses on:

- Vagrant/VirtualBox configuration for a three-node lab.
- Automated Docker Engine installation.
- Container image build and registry publishing.
- Docker Swarm stack configuration and deployment scripts.
- Optional database-free Rack middleware.
- A live HTTP dashboard implemented with HTML, CSS, and JavaScript.
- Demonstration procedures and troubleshooting documentation.

The original documentation is preserved in
[swarm-lab/README.upstream.md](swarm-lab/README.upstream.md).

## Architecture

| Component | Responsibility | Lab address |
|---|---|---|
| Ubuntu host | Runs Vagrant and VirtualBox | Host-specific |
| manager1 | Swarm management and demo ingress endpoint | 192.168.56.11 |
| worker1 | Runs application tasks | 192.168.56.12 |
| worker2 | Runs application tasks | 192.168.56.13 |
| Docker Hub | Stores the prebuilt application image | External registry |
| Browser | Sends probes and displays results | Host or laptop |

The browser accesses port 3001 on manager1. Swarm's routing mesh forwards
requests to application tasks running on the workers.

Two web replicas are requested. Placement preferences encourage spreading
them across workers while allowing both to run on one surviving worker,
provided it has sufficient resources.

All three VMs share one host. This demonstrates VM-level behavior, not
resilience against physical-host failure.

## Technology stack

| Area | Technology |
|---|---|
| Local infrastructure | Vagrant and VirtualBox |
| Guest operating system | Ubuntu |
| Container runtime | Docker Engine |
| Orchestration | Docker Swarm |
| Application | Upstream Ruby on Rails/Puma application |
| Image registry | Docker Hub |
| Demo backend | Optional Rack middleware |
| Demo frontend | HTML, CSS, JavaScript, Canvas |
| Deployment | Swarm stack YAML and shell script |

See the Vagrantfile, Dockerfile, and Gemfile.lock for the configuration
used by this checkout.

## Repository structure

```text
.
├── app/                              # Upstream application
├── config/
│   └── initializers/
│       └── swarm_demo.rb             # Optional demo middleware
├── lib/
│   └── swarm_demo/
│       └── index.html                # Live dashboard
├── swarm-lab/
│   ├── README.upstream.md            # Preserved upstream README
│   ├── infra/
│   │   ├── Vagrantfile
│   │   └── install-docker.sh
│   ├── deploy/
│   │   ├── stack.yml
│   │   └── deploy.sh
│   └── docs/
│       └── images/
├── Dockerfile
├── README.md
└── LICENSE
```

## Live dashboard

| Endpoint | Purpose |
|---|---|
| `/demo` | Live demonstration page |
| `/demo/health` | JSON response from the serving task |

The dashboard displays:

- Successful and failed probes.
- Probe success percentage.
- Latest successful response latency.
- Latency history for the last 60 probes.
- Application release label.
- Swarm node and task identity.
- Container hostname.
- A recent request feed.

The browser waits one second after each completed probe. Requests time out
after four seconds.

These measurements belong to the current browser session. They are not
cluster-wide monitoring, a throughput benchmark, or an availability SLA.
Background tabs may throttle probe timers.

Persistent connections may repeatedly reach the same replica. The request
feed does not guarantee round-robin distribution.

## How the database-free demo works

The middleware is enabled by:

```text
SWARM_DEMO_ENABLED=true
```

It handles the demo routes before normal request middleware that could
access sessions, authentication, or external dependencies.

Rails must still boot successfully. Only the dedicated demo endpoints
avoid those dependencies; the entire application is not database-free.

The stack starts Puma directly, bypassing the upstream entrypoint's
automatic database migrations. Sidekiq is not started in this lab.

Normal application routes, including login, retain their database and
integration requirements.

The demo health check confirms HTTP responsiveness only. It does not
establish full application health.

## Prerequisites

For the default prebuilt-image setup:

- An Ubuntu host with hardware virtualization available.
- Vagrant and a compatible VirtualBox installation.
- Git.
- Internet access for VM images, packages, and container pulls.
- An unused private subnet.
- Enough memory and disk space for the VMs and container images.

Recommended starting resources:

| Resource | Starting point |
|---|---|
| Host RAM | 12–16 GB preferred |
| Host free disk | Approximately 40 GB or more |
| Manager RAM | 2 GB |
| Worker RAM | At least 2 GB each |

Inspect `swarm-lab/infra/Vagrantfile` for actual allocations. These values
are lab starting points, not validated production capacity.

If the Ubuntu host is itself a VM, nested virtualization must be supported
and enabled.

The default network is `192.168.56.0/24`. Change it consistently if it
overlaps your LAN, VPN, or another VM network.

## Quick start — use the prebuilt image

### 1. Clone this fork

Run on the Ubuntu host:

```bash
git clone --branch swarm-lab \
  https://github.com/silvaarohit/patchwork_dashboard.git

cd patchwork_dashboard
```

### 2. Start the lab VMs

```bash
cd swarm-lab/infra

vagrant up --provider=virtualbox
vagrant status
```

Expected machines:

```text
manager1
worker1
worker2
```

The provisioner installs Docker inside each VM.

Verify Docker:

```bash
vagrant ssh manager1 -c "sudo docker --version"
vagrant ssh worker1 -c "sudo docker --version"
vagrant ssh worker2 -c "sudo docker --version"
```

Run Vagrant commands from this `infra` directory.

### 3. Initialize Swarm

Enter manager1:

```bash
vagrant ssh manager1
```

Inside manager1:

```bash
sudo docker swarm init \
  --advertise-addr 192.168.56.11 \
  --data-path-addr 192.168.56.11

sudo docker swarm join-token worker
```

Copy the worker token for the next step. Do not publish it.

Return to the host:

```bash
exit
```

### 4. Join worker1

From the host:

```bash
vagrant ssh worker1
```

Inside worker1, replace `YOUR_WORKER_TOKEN`:

```bash
sudo docker swarm join \
  --token YOUR_WORKER_TOKEN \
  --advertise-addr 192.168.56.12 \
  --data-path-addr 192.168.56.12 \
  192.168.56.11:2377
```

Return to the host:

```bash
exit
```

### 5. Join worker2

```bash
vagrant ssh worker2
```

Inside worker2:

```bash
sudo docker swarm join \
  --token YOUR_WORKER_TOKEN \
  --advertise-addr 192.168.56.13 \
  --data-path-addr 192.168.56.13 \
  192.168.56.11:2377
```

Return to the host:

```bash
exit
```

Verify the cluster:

```bash
vagrant ssh manager1 -c "sudo docker node ls"
```

All three nodes should be Ready and Active.

### 6. Copy the deployment files to manager1

Run on the host from `swarm-lab/infra`:

```bash
vagrant ssh-config manager1 > /tmp/patchwork-manager-ssh.conf
chmod 600 /tmp/patchwork-manager-ssh.conf

ssh -F /tmp/patchwork-manager-ssh.conf manager1 \
  'mkdir -p ~/patchwork-swarm'

scp -F /tmp/patchwork-manager-ssh.conf \
  ../deploy/stack.yml ../deploy/deploy.sh \
  manager1:patchwork-swarm/

rm /tmp/patchwork-manager-ssh.conf
```

### 7. Create the lab environment file

Enter manager1:

```bash
vagrant ssh manager1
cd ~/patchwork-swarm
```

Generate a Rails secret once, when `app.env` does not yet exist:

```bash
umask 077
printf 'SECRET_KEY_BASE=%s\n' "$(openssl rand -hex 64)" > app.env
```

Keep this file private and preserve it between deployments.

Do not commit `app.env`, registry credentials, or Swarm join tokens.

### 8. Deploy the prebuilt image

On manager1:

```bash
export APP_IMAGE="docker.io/silvaarohit/patchwork_dashboard:lab-live-v1"

chmod +x deploy.sh
./deploy.sh
```

The script pulls the image on manager1 and deploys the stack. Worker nodes
pull the image when their tasks are scheduled.

If registry authentication is required:

```bash
sudo docker login docker.io
./deploy.sh
```

The script uses `--with-registry-auth` to pass registry authentication to
the Swarm agents.

If the image repository is private, you must have authorized access.
For public images, authentication may still help with registry pull limits.

### 9. Verify deployment

On manager1:

```bash
sudo docker stack services patchwork
sudo docker service ps --no-trunc patchwork_web
sudo docker service logs --tail 100 patchwork_web
```

Wait for two running replicas.

From the Ubuntu host:

```bash
curl -i http://192.168.56.11:3001/demo/health
```

Expected: HTTP 200 with a JSON response containing:

```json
{
  "status": "ok",
  "scope": "demo-only"
}
```

Additional fields identify the responding container, node, task, release,
and response time.

Open:

```text
http://192.168.56.11:3001/demo
```

Use `/demo`, not the normal login page.

### Remote access from a laptop

If the Ubuntu host is remote, run this on your laptop:

```bash
ssh -N \
  -L 3001:192.168.56.11:3001 \
  YOUR_USER@YOUR_UBUNTU_HOST
```

Then open:

```text
http://localhost:3001/demo
```

The VM's private address does not need to be exposed publicly.

## Network requirements

| Port | Allowed scope | Purpose |
|---|---|---|
| TCP 2377 | Lab nodes to manager | Swarm management |
| TCP/UDP 7946 | Between lab nodes | Node discovery |
| UDP 4789 | Between lab nodes | Overlay traffic |
| TCP 3001 | Demo clients to lab nodes | Published HTTP service |

Keep management and overlay ports restricted to the trusted lab network.

## Client demonstration runbook

### A. Baseline operation

On manager1:

```bash
sudo docker node ls
sudo docker service ps patchwork_web
```

Confirm:

- Both workers are Ready.
- Two application tasks are running.
- Preferably, one task is on each worker.
- The demo page records successful probes.

Reset browser measurements before each scenario.

### B. Rolling configuration release

On manager1:

```bash
sudo docker service update \
  --env-add APP_RELEASE=v2 \
  patchwork_web
```

Observe the dashboard release label changing to v2.

This changes service configuration and replaces tasks using the update
policy. It is not a new application-code release.

Check update status:

```bash
sudo docker service inspect patchwork_web \
  --format '{{json .UpdateStatus}}'
```

Connection reuse may prevent the browser from showing every intermediate
task or both release labels during the transition.

### C. Rollback

After the update completes, before another service change:

```bash
sudo docker service rollback patchwork_web
```

Observe responses returning to the previous release label.

A service rollback restores the previous service specification. It is not
a database rollback.

### D. Worker shutdown

First confirm worker2 hosts a running application task:

```bash
sudo docker service ps patchwork_web
```

On the host, from `swarm-lab/infra`:

```bash
vagrant halt worker2
```

On manager1:

```bash
sudo docker node ls
sudo docker service ps patchwork_web
```

Watch the browser dashboard for request outcomes and the CLI for task
replacement.

Both replicas can run on worker1 if resources allow. Avoid a strict
one-replica-per-node limit if this is the desired recovery behavior.

Keep the browser connected through manager1's address. A stopped worker's
own IP cannot continue accepting requests.

This is a controlled VM shutdown test, not an abrupt power-loss test.

### E. Restore the worker

On the host:

```bash
vagrant up worker2 --provider=virtualbox
```

After worker2 becomes Ready, on manager1:

```bash
sudo docker service update --force patchwork_web
```

Swarm replaces missing tasks automatically but does not automatically
rebalance healthy tasks when a node returns.

The forced rolling replacement lets Swarm schedule new tasks across the
available workers.

## Optional — build your own image

Use this path when changing the application or demo implementation.

Docker Engine is required on the build host. Ruby does not need to be
installed directly on the host because the Dockerfile defines the build
environment.

From the repository root:

```bash
export APP_IMAGE="docker.io/YOUR_DOCKERHUB_USERNAME/patchwork_dashboard:lab-custom-v1"

docker login docker.io
docker build --progress=plain -t "$APP_IMAGE" .
docker push "$APP_IMAGE"
```

On manager1:

```bash
cd ~/patchwork-swarm

export APP_IMAGE="docker.io/YOUR_DOCKERHUB_USERNAME/patchwork_dashboard:lab-custom-v1"

./deploy.sh
```

For changed builds, use a new image tag rather than repeatedly overwriting
the same demonstration tag.

Record the image digest for reproducibility. An image can also be deployed
using its immutable digest reference:

```text
docker.io/USERNAME/REPOSITORY@sha256:ACTUAL_DIGEST
```

## Validation evidence

Populate this table with results from your own recorded run.

| Scenario | Expected observation | Recorded result |
|---|---|---|
| Initial deployment | Two running replicas and HTTP 200 | Not recorded |
| Configuration rollout | Responses change from v1 to v2 | Not recorded |
| Rollback | Responses return to the previous release | Not recorded |
| Worker shutdown | Missing tasks replaced on surviving worker | Not recorded |
| Worker restoration | Ready node and redistribution after rolling replacement | Not recorded |

Do not infer zero downtime from a successful deployment. Browser probes
sample availability and may miss short interruptions.

Store screenshots under:

```text
swarm-lab/docs/images/
```

Useful evidence includes:

- The working live dashboard.
- A release-label transition.
- Task placement after a worker shutdown.
- Both workers restored to Ready.

## Build and test record

Record these details for a repeatable presentation:

| Item | Value |
|---|---|
| Upstream base commit | To be recorded |
| Lab source commit | To be recorded |
| Published image tag | `lab-live-v1` |
| Image digest | To be recorded |
| Test date | To be recorded |
| VM resource allocations | See Vagrantfile; record actual values |
| Observed recovery time | Measure during a controlled run |

The current repository and published image can diverge. Record both the
source revision and image digest when documenting results.

## Troubleshooting

### Image pull fails

Check:

- The repository and tag exist.
- The node can reach Docker Hub.
- Authentication is valid if required.
- The account has access to a private repository.
- Registry rate limits have not been reached.

On manager1:

```bash
sudo docker pull "$APP_IMAGE"
sudo docker service ps --no-trunc patchwork_web
```

### Registry push is denied

Check the namespace, account, and token write permissions.

Use the same Docker CLI user context for login and push. Credentials saved
by `docker login` may differ from those used by `sudo docker push`.

### Normal login page returns HTTP 500

The application login flow requires a database. A successful container
startup does not prove the database or application integrations work.

Use:

```text
/demo
```

for the database-free infrastructure demonstration.

### No application containers appear on manager1

The stack constrains application tasks to workers.

On manager1:

```bash
sudo docker service ps patchwork_web
```

Then inspect containers on the worker hosting the task:

```bash
sudo docker ps \
  --filter label=com.docker.swarm.service.name=patchwork_web
```

### Demo still shows old content

Check the deployed image:

```bash
sudo docker service inspect patchwork_web \
  --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
```

Confirm the new image was built, pushed, and selected during deployment.

### Returning worker remains empty

Swarm does not move healthy tasks solely to rebalance after a node returns.

For this stateless lab:

```bash
sudo docker service update --force patchwork_web
```

### Task fails or restarts

Inspect task history and logs:

```bash
sudo docker service ps --no-trunc patchwork_web
sudo docker service logs --tail 100 patchwork_web
```

Check worker memory, image availability, startup errors, and health-check
results before changing deployment settings.

## Operational lessons

- A service can be running while an application route fails.
- Health checks should clearly state what they validate.
- Image distribution is separate from local image building.
- Container identity, task identity, and node identity are different.
- Automatic failure recovery is different from automatic rebalancing.
- Rolling configuration updates and application-code releases should be
  described accurately.
- CLI changes should eventually be reflected in the deployment files if
  they are intended to persist.

## Limitations

- One manager: no manager high availability.
- One physical host: no physical-host resilience.
- No database, Redis, Mastodon, or user-login validation.
- No durable shared-upload storage demonstration.
- HTTP only on the private demo endpoint.
- Browser measurements are not centralized observability.
- Resource settings are lab values, not production sizing.
- Demo health does not represent complete application health.
- Images and package versions must be pinned for stronger reproducibility.

## Production follow-up

Before considering a production deployment:

- Use three managers across independent failure domains.
- Add resilient ingress and TLS.
- Separate web and background-worker services.
- Manage secrets and restrict network access.
- Validate database compatibility and migration procedures.
- Provide durable shared or object storage.
- Add centralized logs, metrics, and alerting.
- Test backup restoration.
- Run representative load with a worker unavailable.
- Establish image scanning and release controls.

## Stop or remove the lab

From `swarm-lab/infra`, stop the VMs while preserving their data:

```bash
vagrant halt
```

Resume:

```bash
vagrant up --provider=virtualbox
```

To permanently delete the lab VMs and their contents:

```bash
vagrant destroy
```

Review the confirmation carefully. Repository files remain, but VM-local
data is deleted.

## License and attribution

This fork builds upon
[Patchwork Dashboard](https://github.com/patchwork-hub/patchwork_dashboard),
whose upstream code is licensed under AGPL-3.0.

See [LICENSE](LICENSE). Preserve applicable license and attribution notices
when distributing code or images.

This is an independent infrastructure demonstration. It is not an official
Patchwork deployment guide.