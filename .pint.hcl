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
