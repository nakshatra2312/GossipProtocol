defmodule GossipSimulator do
  alias GossipSimulator.Module.Supervisor 
  
  def main(args \\ []) do    
    args
    |> parse_string

    receive do
      { :message, message } -> IO.puts message
      {:terminate, start_time, message} -> 
        IO.puts message
        time = :os.system_time(:millisecond) - start_time
        IO.puts "Terminate Main Method after #{time} milliseconds"        
        
        #Process.exit(self(), :kill)
    end    
  end

  def listener(num_nodes, main_pid, nodes, start_time, n) do
    if(num_nodes > 0) do
      receive do
        { :start, start_tim} -> listener(num_nodes, main_pid, nodes, start_tim, n)
        { :stop } -> IO.puts "DONE"
        { :message, message } ->         
          if num_nodes < 0.79 * n do            
            #IO.puts "#{message}"
            send main_pid, {:terminate, start_time, message}
          else
            listener(num_nodes - 1, main_pid, nodes, start_time, n)
          end
          #IO.puts "#{message}, Index: #{num_nodes}"
          listener(num_nodes - 1, main_pid, nodes, start_time, n)
        _ -> IO.puts "Exception Occured"         
      end      
    else 
        send main_pid, {:terminate, start_time}
    end
  end

  def compute_sum_and_weight(num_nodes, return) do
    if num_nodes > 0 do
      list = GenServer.call(create_node_name(num_nodes), {:server_state})
      sum = Enum.at(list, 0)
      weight = Enum.at(list, 1)
      ratio = sum/weight
      IO.puts "Sum: #{sum} Weight: #{weight} Ratio: #{ratio}"     
      return = compute_sum_and_weight(num_nodes - 1, [Enum.at(return, 0) + Enum.at(list, 0), Enum.at(return, 1) + Enum.at(list, 1)])
    end
    return
  end

  defp parse_string(args) do    
    num_nodes = String.to_integer(Enum.at(args,0))
    topology =  Enum.at(args,1)
    algorithm = Enum.at(args,2)
    #IO.puts "<plotty: draw, #{num_nodes}>"
    {:ok, _} = Supervisor.start_link
    main_pid = self()
    IO.puts "Building Topology"
    if topology == "2D" or topology == "imp2D" do
      square_root = round(:math.ceil(:math.sqrt(num_nodes)))
      num_nodes = round(:math.pow(square_root,2))      
      listener_pid = spawn fn -> listener(num_nodes, main_pid, 0.8 * num_nodes, 0, num_nodes) end
      add_worker(1, num_nodes, topology, listener_pid)
      if topology == "imp2D" do
        add_random_additional_nodes(1, num_nodes)
      end
    else
      listener_pid = spawn fn -> listener(num_nodes, main_pid, 0.8 * num_nodes, 0, num_nodes) end
      add_worker(1, num_nodes, topology, listener_pid)
    end    

    start_time = :os.system_time(:millisecond)    
    send listener_pid, {:start, start_time} 
    case algorithm do
      "gossip" -> 
          IO.puts "Starting Gossip"
          GenServer.cast(:node1, {:gossip, :node1, "message", topology, num_nodes})
      "push-sum" -> 
          IO.puts "Starting Push-Sum"
          GenServer.cast(:node1, {:push_sum, :node1, 0, 0, topology, num_nodes})
      _ -> send self(), {:message, "Invalid Algorithm"}
      end
  end

  defp add_worker(index, num_nodes, topology, listener_pid) do
    if index <= num_nodes do
      worker_name = create_node_name(index)
      neighbours = {}
      case topology do
        "full" -> #neighbours = find_full_neighbours([], index, num_nodes)
                  neighbours = {}
        "2D" -> neighbours = find_2D_neighbours(index, num_nodes)
        "line" -> neighbours = find_line_neighbours(index, num_nodes)
        "imp2D" -> neighbours = find_2D_neighbours(index, num_nodes)
        _ -> send self(), {:message, "Invalid Topology"}
      end     
      
      Supervisor.add_children(worker_name, index, num_nodes, neighbours, listener_pid)      
      add_worker(index + 1, num_nodes, topology, listener_pid)
    end  
  end 

  def find_full_neighbours(list, index, num_nodes) do
    if num_nodes > 0 do
      if num_nodes == index do
        list = find_full_neighbours(list,index, num_nodes - 1)
      else
        list = find_full_neighbours([create_node_name(num_nodes) | list], index, num_nodes - 1)
      end      
    end
    list    
  end

  def find_2D_neighbours(index, num_nodes) do
    square_root = round(:math.ceil(:math.sqrt(num_nodes)))
    #num_nodes = round(:math.pow(square_root,2))    
    corner3 = num_nodes - square_root + 1
    case index do
      1 -> {create_node_name(1), create_node_name(2), create_node_name(square_root + 1)}
      ^square_root -> {create_node_name(square_root), create_node_name(square_root - 1), create_node_name(2 * square_root)}
      ^corner3 -> {create_node_name(corner3), create_node_name(corner3 - square_root), create_node_name(corner3 + 1)}
      ^num_nodes -> {create_node_name(num_nodes), create_node_name(num_nodes - 1), create_node_name(num_nodes - square_root)}

      i when i in 2..square_root-1 -> {create_node_name(i), create_node_name(i - 1), create_node_name(i + 1), create_node_name(i + square_root)}
      i when i in corner3 + 1..num_nodes-1 -> {create_node_name(i), create_node_name(i - 1), create_node_name(i + 1), create_node_name(i - square_root)}
      _ -> else_clause(index, square_root)
    end
  end

  defp else_clause(index, square_root) do
    first_column = for x <- 1..square_root-2, do: (square_root * x) + 1    
    last_column = for x <- 1..square_root-2, do: (square_root * x) + square_root
    if index in first_column do
      {create_node_name(index), create_node_name(index - square_root), create_node_name(index + 1), create_node_name(index + square_root)}
    else
      if index in last_column do
        {create_node_name(index), create_node_name(index - square_root), create_node_name(index - 1), create_node_name(index + square_root)}
      else
        {create_node_name(index), create_node_name(index - 1), create_node_name(index + 1), create_node_name(index + square_root), create_node_name(index - square_root)}
      end
    end    
  end  

  defp find_line_neighbours(index, num_nodes) do    
    if num_nodes == 1 do
      {create_node_name(num_nodes)}
    else
      case index do
        1 -> {create_node_name(index), create_node_name(index + 1)}
        ^num_nodes -> {create_node_name(index), create_node_name(index - 1)}
        _ -> {create_node_name(index), create_node_name(index - 1), create_node_name(index + 1)}
      end
    end
  end  

  defp add_random_additional_nodes(index, num_nodes) do
    if index <= num_nodes do
      name1 = create_node_name(index)
      rand = Enum.random(1..num_nodes)
      name2 = create_node_name(rand)
      GenServer.cast(name1, {:add_additional_imp2D_nodes, name2})
      GenServer.cast(name2, {:add_additional_imp2D_nodes, name1})
      add_random_additional_nodes(index + 1, num_nodes)
    end
  end    

  defp create_node_name(index) do
    :"node#{index}"
  end

  def random_neighbour_pick(neighbours) do        
    #neigh = Enum.at(Enum.at(neighbours, 0),0)
    index = Enum.random(0..length(neighbours)-1)
    Enum.at(neighbours, index)
end     

end
