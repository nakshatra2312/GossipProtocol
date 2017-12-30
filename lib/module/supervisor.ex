defmodule GossipSimulator.Module.Supervisor do
    use Supervisor
    alias GossipSimulator.Module.Node

    def start_link do        
        Supervisor.start_link(__MODULE__, [],  name: :gossip_supervisor)       
    end

    def init(_) do
        children = 
        [            
            worker(Node, []),                        
        ]        
        supervise(children, strategy: :simple_one_for_one)        
    end

    def add_children(name, index, num_nodes, neighbours, listener_pid) do        
        args = [name, neighbours, listener_pid]        
        Supervisor.start_child(:gossip_supervisor, [args])
    end

end
