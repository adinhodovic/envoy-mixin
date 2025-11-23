rule {
  match {
    name = "EnvoyUpstreamHighHttp4xxErrorRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "EnvoyUpstreamHighHttp5xxErrorRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "EnvoyCircuitBreakerOpen"
  }
  disable = ["promql/regexp"]
}


rule {
  match {
    name = "EnvoyUpstreamUnhealthyHosts"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "EnvoyUpstreamConnectionFailures"
  }
  disable = ["promql/regexp"]
}
