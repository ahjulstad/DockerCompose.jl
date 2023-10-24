module DockerCompose
import XKPasswd
import FunSQL
using DBInterface
using ODBC

export sqlserver

mutable struct Container
    name::String
    port
    password
    genstring::String
    function Container(name, port, password, genstring) 
        c = new(name, port, password, genstring)
        finalizer(delete_container, c)
    end
end

function delete_container(c::Container)
    @async println("Stopping $(c.name)")
    run(pipeline(IOBuffer(c.genstring), `docker compose -f - down`))
end

function sqlserver()
    n = first(XKPasswd.generate(2, delimstr="-"))
    return sqlserver(n)
end

function sqlserver(n::String)
    name = "dcjlcont-"*n
    pwd = "G1n-"*first(XKPasswd.generate(4, delimstr="-"))
    project = "dcjlproj-"*n
    dockerstring = """
    version: '3.8'
    name: '$project'
    services:
        msdb:
            image: mcr.microsoft.com/mssql/server:2022-preview-ubuntu-22.04
            container_name: '$name'
            restart: no
            environment:
                ACCEPT_EULA: 'Y'
                MSSQL_SA_PASSWORD: '$pwd'
                MSSQL_PID: Evaluation
            ports:
                - 127.0.0.1::1433
    """
    run(pipeline(IOBuffer(dockerstring), `docker compose -f - up -d` ))
    port = first(match(r"(\d+)(?!.*\d)", read(`docker port $name`, String)))
    c = Container(name, port, pwd, dockerstring)
    return c
end

function connect(c::Container)
    conn = ODBC.Connection("Driver={ODBC Driver 18 for SQL Server};Server=127.0.0.1,$(c.port);Encrypt=no", "sa", c.password)
end

function funconnect(c::Container)
    dialect = FunSQL.SQLDialect(:sqlserver)
    conn = DBInterface.connect(FunSQL.DB{ODBC.Connection}, "Driver={ODBC Driver 18 for SQL Server};Server=127.0.0.1,$(c.port);Encrypt=no", "sa", c.password, dialect=dialect)
end

end # module DockerCompose
