defmodule GossipSimulator.Module.Node do
    use GenServer 

    def start_link(args \\ []) do        
        name = args |> Enum.at(0)
        neighbour = args |> Enum.at(1)   
        listener_pid = args |> Enum.at(2)         
        name_to_str = to_string(name)
        count = String.slice(name_to_str, 4..-1)
        tuple = Integer.parse(count)               
        initial_sum = elem(tuple,0)
        initial_weight = 1
        counter = 0;
        #IO.puts "Gen Server Started: #{name}"
        #IO.inspect "---#{name}------#{neighbour}-------"             
        GenServer.start_link(__MODULE__, [0, false, listener_pid, neighbour, false, initial_sum, initial_weight, counter], name: name)        
    end

    def handle_cast({:gossip, name, message, topology, num_nodes}, state) do   
        #IO.inspect state     
        [num | tail] = state
        [message_flag | tail] = tail
        [listener_pid | tail] = tail
        [neighbours | tail] = tail
        [first_message | tail] = tail   
        [state_sum | tail] = tail
        [state_weight | tail] = tail
        [state_counter | _] = tail        
          
        #IO.puts "In Node: #{name} - num = #{num}"
        if num < 10 do
            if topology == "full" do
                index = Enum.random(1..num_nodes)
                neighbour_name = :"node#{index}"
                GenServer.cast(neighbour_name, {:gossip, neighbour_name, message, topology, num_nodes})
                GenServer.cast(name, {:gossip_self_call, name, message, topology, num_nodes})               
                {:noreply, [num + 1] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [state_sum] ++ [state_weight] ++ [state_counter]}    
            else
                if first_message == false do
                    random_neighbour = random_neighbour_pick(neighbours, 1)
                    #IO.inspect "Random : #{random_neighbour}"
                    GenServer.cast(random_neighbour, {:gossip, random_neighbour, message, topology, num_nodes})
                    #:timer.sleep(1000)
                    GenServer.cast(name, {:gossip_self_call, name, message, topology, num_nodes})
                    #name_to_str = to_string(name)
                    #count = String.slice(name_to_str, 4..-1)
                    #IO.puts "<plotty: infected, #{count}>"
                    {:noreply, [num + 1] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [true] ++ [state_sum] ++ [state_weight] ++ [state_counter]}
                else
                    random_neighbour = random_neighbour_pick(neighbours, 0)
                    #IO.inspect "Random : #{random_neighbour}"
                    GenServer.cast(random_neighbour, {:gossip, random_neighbour, message, topology, num_nodes})
                    #:timer.sleep(1000)
                    GenServer.cast(name, {:gossip_self_call, name, message, topology, num_nodes})
                    #name_to_str = to_string(name)
                    #count = String.slice(name_to_str, 4..-1)
                    #IO.puts "<plotty: infected, #{count}>"                    
                    {:noreply, [num + 1] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [state_sum] ++ [state_weight] ++ [state_counter]}    
                end
            end
        else
            if message_flag == false do
                #IO.puts "Node Terminated: #{name} -- #{num}"
                #name_to_str = to_string(name)
                #count = String.slice(name_to_str, 4..-1)               
                #IO.puts "<plotty: inactive, #{count}>"
                send listener_pid, {:message, "All Nodes Terminated after #{num} rumors"} 
                if topology == "line" do
                    send_to_all_nodes(message, neighbours, topology, 0, num_nodes)
                end                 
                {:noreply, [num] ++ [true] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [state_sum] ++ [state_weight] ++ [state_counter]}
            else       
            {:noreply, state}
            end                  
        end        
    end

    def send_to_all_nodes(message, neighbours, topology, count, num_nodes) do        
        if count < tuple_size(neighbours) do            
            :timer.sleep(1)       
            GenServer.cast(elem(neighbours, count), {:gossip, elem(neighbours, count), message, topology, num_nodes})
            send_to_all_nodes(message, neighbours, topology, count + 1, num_nodes)
        end
    end

    def handle_cast({:gossip_self_call, name, message, topology, num_nodes}, state) do
        [num | tail] = state      
        [message_flag | tail] = tail
        [_ | tail] = tail  
        [neighbours | _] = tail

        if num < 10 or message_flag == false do
            if topology == "full" do
                index = Enum.random(1..num_nodes)
                random_neighbour = :"node#{index}" 
                GenServer.cast(random_neighbour, {:gossip, random_neighbour, message, topology, num_nodes})
                #:timer.sleep(1000)
                GenServer.cast(name, {:gossip_self_call, name, message, topology, num_nodes})                
            else
                random_neighbour = random_neighbour_pick(neighbours, 0)
                GenServer.cast(random_neighbour, {:gossip, random_neighbour, message, topology, num_nodes})
                #:timer.sleep(1000)
                GenServer.cast(name, {:gossip_self_call, name, message, topology, num_nodes})
            end            
        end
        {:noreply, state}
    end

    def handle_cast({:add_additional_imp2D_nodes, name}, state) do
        #IO.inspect(state, label: "#{self_name} Before State: ")
        [num | tail] = state
        [message_flag | tail] = tail
        [listener_pid | tail] = tail
        [neighbours | tail] = tail
        [first_message | tail] = tail   
        [state_sum | tail] = tail
        [state_weight | tail] = tail
        [state_counter | _] = tail
        list = Tuple.to_list(neighbours)
        new_list = Enum.uniq([name | list])
        new_neighbour = List.to_tuple(new_list)
        new_state = [num] ++ [message_flag] ++ [listener_pid] ++ [new_neighbour] ++ [first_message] ++ [state_sum] ++ [state_weight] ++ [state_counter]
        #IO.inspect(new_state, label: "#{self_name} After State: ") 
        {:noreply, new_state}
    end  
    
    def handle_cast({:push_sum, name, sum, weight, topology, num_nodes}, state) do        
        [num | tail] = state
        [message_flag | tail] = tail
        [listener_pid | tail] = tail
        [neighbours | tail] = tail
        [first_message | tail] = tail
        [state_sum | tail] = tail
        [state_weight | tail] = tail
        [state_counter | _] = tail        
        
        new_sum = state_sum + sum
        new_weight = state_weight + weight
        if state_weight == 0 or new_weight == 0 do            
            send listener_pid, {:message, "All nodes converged using push-sum"}  
            {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [new_sum] ++ [new_weight] ++ [state_counter]} 
        else
            if state_counter < 3 do
                old_ratio = state_sum/state_weight
                new_ratio = new_sum/new_weight
                difference = abs(old_ratio - new_ratio)                       
                if  difference <= :math.pow(10, -10) do               
                    state_counter = state_counter + 1                
                    if state_counter == 3 do                    
                        send listener_pid, {:message, "All nodes converged using push-sum"}  
                        {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [new_sum] ++ [new_weight] ++ [state_counter]} 
                    else                    
                        if first_message == false do
                            GenServer.cast(name, {:push_sum_self_call, name, topology, num_nodes})
                            {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [true] ++ [new_sum] ++ [new_weight] ++ [state_counter]}
                        else
                            {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [new_sum] ++ [new_weight] ++ [state_counter]} 
                        end                                      
                    end
                else
                    counter = 0                
                    if first_message == false do
                        GenServer.cast(name, {:push_sum_self_call, name, topology, num_nodes})
                        {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [true] ++ [new_sum] ++ [new_weight] ++ [counter]}
                    else
                        {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [new_sum] ++ [new_weight] ++ [counter]}
                    end                
                end   
            else
                #IO.puts "#{name} #{new_sum}"
                #{:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [new_sum] ++ [new_weight] ++ [state_counter]}                   
                {:noreply, state}
            end
        end

    end

    def handle_cast({:push_sum_self_call, name, topology, num_nodes}, state) do
        [num | tail] = state
        [message_flag | tail] = tail
        [listener_pid | tail] = tail
        [neighbours | tail] = tail
        [first_message | tail] = tail
        [state_sum | tail] = tail
        [state_weight | tail] = tail
        [state_counter | _] = tail
           
        if state_counter < 3 do
            if topology == "full" do
                index = Enum.random(1..num_nodes)
                random_neighbour = :"node#{index}"               
                GenServer.cast(random_neighbour, {:push_sum, random_neighbour, state_sum/2, state_weight/2, topology, num_nodes})
                Process.sleep(Enum.random(0..100))
                GenServer.cast(name, {:push_sum_self_call, name, topology, num_nodes})
                {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [state_sum/2] ++ [state_weight/2] ++ [state_counter]}
            else
                random_neighbour = random_neighbour_pick(neighbours, 0)
                GenServer.cast(random_neighbour, {:push_sum, random_neighbour, state_sum/2, state_weight/2, topology, num_nodes})
                Process.sleep(Enum.random(0..100))
                GenServer.cast(name, {:push_sum_self_call, name, topology, num_nodes})
                {:noreply, [num] ++ [message_flag] ++ [listener_pid] ++ [neighbours] ++ [first_message] ++ [state_sum/2] ++ [state_weight/2] ++ [state_counter]}
            end
        else
            {:noreply, state}
        end        
    end 

    def handle_call({:server_state}, _from, state) do
        [_ | tail] = state
        [_ | tail] = tail
        [_ | tail] = tail
        [_ | tail] = tail
        [_ | tail] = tail
        [state_sum | tail] = tail
        [state_weight | tail] = tail
        [_ | _] = tail
        {:reply, [state_sum, state_weight],state}              
    end

    def random_neighbour_pick(neighbours, start_index) do        
        #neigh = Enum.at(Enum.at(neighbours, 0),0)
        index = Enum.random(start_index..tuple_size(neighbours)-1)
        elem(neighbours, index)
    end   

end