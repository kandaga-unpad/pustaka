## Runner script to execute authorization seeds during mix run
## This keeps the implementation module separate (.ex) while providing a script
## that Mix can execute (mix run <file>). It will load the module and call run/0.

Code.require_file("priv/repo/seeds/authorization_seeds.ex")

Voile.Repo.Seeds.AuthorizationSeeds.run()
