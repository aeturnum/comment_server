alias CommentServer.Database.Operations

Operations.drop_tables()
Operations.setup_tables()
CommentServer.Admin.SystemUser.setup_users()
CommentServer.init(:ok)

ExUnit.start()
