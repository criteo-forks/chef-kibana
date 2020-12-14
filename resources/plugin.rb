# frozen_string_literal: true

resource_name :kibana_plugin

property :name, String, name_property: true
property :url, String
property :user, String, default: 'root'
property :kibana_home, String, default: ::File.join(node['kibana']['base_dir'], 'current')
property :plugins_registry, String, default: ::File.join(node['kibana']['base_dir'], 'current', 'installedPugins.json')

default_action :nothing

load_current_value do
  if ::File.exist?(plugins_registry)
    pfile = ::File.open(plugins_registry)
    plugins = JSON.parse(pfile.read)
    url plugins[name]
  end
end

def plugin_exists?(name)
  list_arg = node['kibana']['version'] > 6 ? 'bin/kibana-plugin list --allow-root' : 'bin/kibana-plugin list'
  cmd_line = list_arg.to_s
  cmd = Mixlib::ShellOut.new(cmd_line, cwd: kibana_home)
  cmd.run_command
  cmd.stdout.include? name
end

def update_plugin_reg(action)
  plugins = ::File.exist?(plugins_registry) ? JSON.parse(::File.read(plugins_registry)) : {}
  case action
  when 'add'
    plugins[name] = new_resource.url
  when 'remove'
    plugins.delete(name)
  end
  ::File.open(plugins_registry, 'w') { |file| file.write(JSON.pretty_generate(plugins)) }
end

action :install do
  install_arg = node['kibana']['version'] > 6 ? "bin/kibana-plugin install #{new_resource.url} --allow-root" : "bin/kibana-plugin install #{new_resource.url}"
  plugin_install = install_arg.to_s
  execute 'plugin-install' do
    cwd new_resource.kibana_home
    command plugin_install
    user new_resource.user
    not_if { plugin_exists?(new_resource.name) }
  end
  update_plugin_reg('add')
end

action :remove do
  remove_arg = node['kibana']['version'] > 6 ? "bin/kibana-plugin remove #{new_resource.name} --allow-root" : "bin/kibana-plugin remove #{new_resource.name}"
  plugin_remove = remove_arg.to_s
  execute 'plugin-remove' do
    cwd new_resource.kibana_home
    command plugin_remove
    user new_resource.user
    only_if { plugin_exists?(new_resource.name) }
  end
  update_plugin_reg('remove')
end

action :update do
  if new_resource.url != current_resource.url
    kibana_plugin new_resource.name do
      action :remove
      kibana_home new_resource.kibana_home
      user new_resource.user
      only_if { plugin_exists?(new_resource.name) }
    end
    kibana_plugin new_resource.name do
      action :install
      url new_resource.url
      kibana_home new_resource.kibana_home
      user new_resource.user
    end
  end
end