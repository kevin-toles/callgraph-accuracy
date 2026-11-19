# Call-graph accuracy by language

Untouched repos (holdout + random sample). The target is per repo: every reviewed repo at 98% or above, so the worst repo is the figure that counts. The pooled census (edge-weighted, dominated by large repos) is shown alongside.

| language | worst repo | meets per-repo target | pooled census | repos reviewed | per-repo census (sample) | pending |
|---|---|---|---|---|---|---|
| c | h-aws-c-common 99.20% | yes | 99.68% (107 of 33731) | 4 | h-aws-c-common 99.2% (49/50); s-crypto 99.9% (49/50); s-xv6-riscv 99.8% (47/50); s-mesa-drm 99.8% (50/50) |  |
| cpp | s-nvidia-flex 98.49% | yes | 98.77% (811 of 65923) | 4 | h-wabt 98.7% (49/50); s-falco 98.8% (50/50); s-nvidia-streamline 99.1% (49/50); s-nvidia-flex 98.5% (46/50) |  |
| csharp | s-particular-nservicebus.rabbitmq 98.75% | yes | 99.10% (153 of 17065) | 4 | h-framerecorder 98.8% (48/50); s-particular-nservicebus.rabbitmq 98.8% (50/50); s-xr-interaction-examples 99.6% (49/50); s-unity-cloud-reference-project 99.1% (49/50) |  |
| elixir | s-realtime 99.96% | yes | 99.99% (4 of 49759) | 4 | h-phoenix 100.0% (48/50); s-elixir 100.0% (49/50); s-realtime 100.0% (50/50); s-rabbitmq 100.0% (50/50) |  |
| go | s-gorm 98.72% | yes | 98.99% (129 of 12823) | 4 | h-chi 99.9% (50/50); s-chaosmonkey 100.0% (48/50); s-robpike-ivy 98.9% (50/50); s-gorm 98.7% (50/50) |  |
| groovy | s-grails-data-mongodb 98.84% | yes | 99.20% (75 of 9359) | 4 | h-dbb 99.2% (48/50); s-grails-gradle 99.5% (49/50); s-grails-profiles 99.0% (50/50); s-grails-data-mongodb 98.8% (43/50) |  |
| haskell | s-agda 99.11% | yes | 99.47% (756 of 141573) | 4 | h-pandoc 99.9% (50/50); s-shellcheck 100.0% (50/50); s-haskell 100.0% (50/50); s-agda 99.1% (46/50) |  |
| java | h-replicate 98.97% | yes | 99.47% (186 of 35314) | 4 | h-replicate 99.0% (49/50); s-orc 99.6% adjudicated (raw 99.0%) (48/50); s-commons-lang 99.4% (48/50); s-williamfiset-Algorithms 99.7% (50/50) |  |
| javascript | s-newman 98.46% | yes | 99.57% (233 of 54731) | 4 | h-uptime-kuma 99.7% (48/50); s-newman 98.5% adjudicated (raw 97.9%) (50/50); s-snarkjs 99.5% (49/50); s-pdf-js 99.6% (49/50) |  |
| kotlin | s-ktlint 98.93% | yes | 99.58% (381 of 89786) | 4 | h-mosaic 99.6% (42/50); s-okhttp 99.7% (45/50); s-coil 99.6% (49/50); s-ktlint 98.9% (36/50) |  |
| lua | s-apisix 98.65% | yes | 99.36% (324 of 50711) | 4 | h-luvit 100.0% (50/50); s-apisix 98.7% (49/50); s-lua 99.9% (50/50); s-kong 99.5% (49/50) |  |
| objc | s-moltenvk 98.41% | yes | 99.27% (261 of 35518) | 4 | h-oreilly-objc 99.7% (39/50); s-jsonkit 99.8% (49/50); s-reachability 98.7% (48/50); s-moltenvk 98.4% (50/50) |  |
| ocaml | h-dune 98.68% | yes | 99.22% (2905 of 374268) | 4 | h-dune 98.7% (39/50); s-semgrep 99.2% (48/50); s-spark2014 99.3% (46/50); s-ocaml 99.6% (37/50) |  |
| php | s-composer 98.86% | yes | 99.03% (278 of 28539) | 4 | h-pdepend 99.3% (50/50); s-php-parser 99.3% (50/50); s-composer 98.9% (48/50); s-laminas 99.5% (49/50) |  |
| python | s-trlx 98.75% | yes | 99.37% (106 of 16841) | 4 | h-distilabel 99.8% (50/50); s-trlx 98.8% (50/50); s-fastai 99.3% (50/50); s-codet5 99.4% (50/50) |  |
| ruby | s-fluentd 98.19% | yes | 99.06% (477 of 50986) | 4 | h-roda 99.1% (44/50); s-sidekiq 98.3% (49/50); s-fluentd 98.2% (50/50); s-rubygems 99.7% (50/50) |  |
| rust | s-quinn 98.39% | yes | 99.24% (605 of 79857) | 4 | h-rtic 98.8% (49/50); s-quinn 98.4% (49/50); s-delta-rs 99.4% (49/50); s-rust-gpu 99.5% (49/50) |  |
| scala | h-fs2 98.16% | yes | 98.78% (1026 of 84329) | 4 | h-fs2 98.2% (46/50); s-codepropertygraph 98.7% (49/50); s-zio 98.9% (45/50); s-doobie 99.0% (50/50) |  |
| typescript | s-dafny-vscode 98.12% | yes | 99.27% (537 of 73549) | 4 | h-mcp-servers 99.0% (45/50); s-stripe-node 98.2% (49/50); s-dafny-vscode 98.1% adjudicated (raw 97.8%) (47/50); s-vue 99.4% (48/50) |  |
| zig | s-input 98.36% | yes | 98.63% (2570 of 187918) | 4 | h-roc 98.6% (48/50); s-input 98.4% (49/50); s-renderer 99.1% (47/50); s-config 98.9% (49/50) |  |

## Development repos (fixes were tuned on these)

| language | repo | report | sample | recall | census |
|---|---|---|---|---|---|
| c | tmux | tmux_report.v3.md | 50/50 | 0 of 76 | 98.6% |
| cpp | cppfront | cppfront_report.v5.md | 48/50 | 0 of 20 | 93.4% |
| cpp | drogon | drogon_report.v5.md | 50/50 | 2 of 110 | 94.0% |
| csharp | iddd | iddd_report.v3.md | 50/50 | 0 of 32 | 99.5% |
| elixir | ecto | ecto_report.v4.md | 50/50 | 0 of 47 | 99.5% |
| go | connect-go | connect-go_report.v3.md | 50/50 | 0 of 93 | 98.3% |
| go | echo | echo_report.v3.md | 49/50 | 7 of 38 | 98.7% |
| groovy | grails-core | grails-core_report.v3.md | 49/50 | 0 of 45 | ? |
| haskell | hadolint | hadolint_report.v4.md | 48/50 | 1 of 63 | 99.5% |
| java | hystrix | hystrix_report.v3.md | 50/50 | 0 of 58 | ? |
| java | zuul | zuul_report.v3.md | 50/50 | 0 of 72 | ? |
| javascript | koa | koa_report.v3.md | 50/50 | 0 of 20 | 99.7% |
| kotlin | moshi | moshi_report.v3.md | 40/50 | 1 of 33 | 84.7% |
| lua | lite-xl | lite-xl_report.v3.md | 50/50 | 0 of 31 | 99.8% |
| objc | libs-base | libs-base_report.v5.md | 48/50 | 0 of 83 | 98.7% |
| ocaml | mirage | mirage_report.v4.md | 45/50 | 1 of 45 | 99.4% |
| php | guzzle | guzzle_report.v3.md | 49/50 | 1 of 32 | ? |
| python | trl | trl_report.v3.md | 50/50 | 2 of 160 | 99.8% |
| ruby | devise | devise_report.v3.md | 50/50 | 0 of 47 | ? |
| rust | just | just_report.v3.md | 50/50 | 0 of 70 | ? |
| scala | circe | circe_report.v3.md | 49/50 | 0 of 47 | ? |
| typescript | openrouter | openrouter_report.v3.md | 47/50 | 0 of 28 | 95.7% |
| typescript | zod | zod_report.v3.md | 50/50 | 0 of 50 | 97.7% |
| zig | ghostty-font | ghostty-font_report.v5.md | 45/50 | 2 of 23 | 90.5% |
