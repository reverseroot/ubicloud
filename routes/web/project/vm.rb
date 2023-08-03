# frozen_string_literal: true

class CloverWeb
  hash_branch(:project_prefix, "vm") do |r|
    @serializer = Serializers::Web::Vm

    r.get true do
      @vms = serialize(@project.vms_dataset.authorized(@current_user.id, "Vm:view").all)

      view "vm/index"
    end

    r.post true do
      Authorization.authorize(@current_user.id, "Vm:create", @project.id)
      ps_id = r.params["private-subnet-id"].empty? ? nil : UBID.parse(r.params["private-subnet-id"]).to_uuid
      Authorization.authorize(@current_user.id, "PrivateSubnet:view", ps_id)
      st = Prog::Vm::Nexus.assemble(
        r.params["public-key"],
        @project.id,
        name: r.params["name"],
        unix_user: r.params["user"],
        size: r.params["size"],
        location: r.params["location"],
        boot_image: r.params["boot-image"],
        storage_size_gib: r.params["storage-size-gib"].to_i,
        private_subnet_id: ps_id,
        enable_ip4: r.params.key?("enable-ip4")
      )

      flash["notice"] = "'#{r.params["name"]}' will be ready in a few minutes"

      r.redirect "#{@project.path}#{st.vm.path}"
    end

    r.on "create" do
      r.get true do
        Authorization.authorize(@current_user.id, "Vm:create", @project.id)
        @subnets = Serializers::Web::PrivateSubnet.serialize(@project.private_subnets_dataset.authorized(@current_user.id, "PrivateSubnet:view").all)
        view "vm/create"
      end
    end
  end
end