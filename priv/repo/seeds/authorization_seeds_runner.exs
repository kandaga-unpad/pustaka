## Runner script to execute authorization seeds during mix run
## This keeps the implementation module separate (.ex) while providing a script
## that Mix can execute (mix run <file>). It will load the module and call run/0.

# In releases, use :code.priv_dir to find the correct path
seed_path =
  if Code.ensure_loaded?(Mix) do
    # Development/test - use relative path
    "priv/repo/seeds/authorization_seeds.ex"
  else
    # Production release - use priv_dir
    Path.join([:code.priv_dir(:voile), "repo", "seeds", "authorization_seeds.ex"])
  end

Code.require_file(seed_path)

Voile.Repo.Seeds.AuthorizationSeeds.run()
