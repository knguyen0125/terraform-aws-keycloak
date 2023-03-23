# AWS Keycloak Terraform Module

This module deploys a production-ready Keycloak cluster to AWS.

## Health Checks

Starting Keycloak 21, the official Docker image no longer contain `curl`, which make it impossible to use
the `HEALTHCHECK` instruction for ECS.

Strictly speaking, we don't need a health check for Keycloak itself, as this module also provision a load balancer in
front of the cluster, which will perform health checks on the instances.
