#include "include/tray_manager/tray_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#ifdef HAVE_AYATANA
#include <libayatana-appindicator/app-indicator.h>
#else
#include <libappindicator/app-indicator.h>
#endif
#include <algorithm>
#include <cstring>
#include <map>

#define TRAY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), tray_manager_plugin_get_type(), \
                              TrayManagerPlugin))

TrayManagerPlugin* plugin_instance;

AppIndicator* indicator = nullptr;
GtkWidget* menu = nullptr;

struct _TrayManagerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  GDBusConnection* session_bus;
  guint session_bus_filter_id;
  gchar* pending_activation_token;
};

G_DEFINE_TYPE(TrayManagerPlugin, tray_manager_plugin, g_object_get_type())

// Gets the window being controlled.
GtkWindow* get_window(TrayManagerPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

guint32 get_activation_timestamp() {
  guint32 timestamp = gtk_get_current_event_time();
#ifdef GDK_WINDOWING_X11
  if (timestamp == GDK_CURRENT_TIME) {
    GtkWindow* window = get_window(plugin_instance);
    GdkWindow* gdk_window =
        window == nullptr ? nullptr : gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr && GDK_IS_X11_WINDOW(gdk_window)) {
      timestamp = gdk_x11_get_server_time(gdk_window);
    }
  }
#endif
  return timestamp;
}

static gboolean set_pending_activation_token(gpointer data) {
  if (plugin_instance != nullptr) {
    const gchar* activation_token = static_cast<const gchar*>(data);
    g_free(plugin_instance->pending_activation_token);
    plugin_instance->pending_activation_token =
        *activation_token == '\0' ? nullptr : g_strdup(activation_token);
  }
  return G_SOURCE_REMOVE;
}

static GDBusMessage* session_bus_filter(GDBusConnection* connection,
                                        GDBusMessage* message,
                                        gboolean incoming,
                                        gpointer) {
  if (!incoming ||
      g_dbus_message_get_message_type(message) !=
          G_DBUS_MESSAGE_TYPE_METHOD_CALL ||
      g_strcmp0(g_dbus_message_get_interface(message),
                "org.kde.StatusNotifierItem") != 0 ||
      g_strcmp0(g_dbus_message_get_member(message),
                "ProvideXdgActivationToken") != 0) {
    return message;
  }

  GVariant* body = g_dbus_message_get_body(message);
  if (body == nullptr || !g_variant_is_of_type(body, G_VARIANT_TYPE("(s)"))) {
    return message;
  }

  const gchar* activation_token = nullptr;
  g_variant_get(body, "(&s)", &activation_token);

  g_main_context_invoke_full(nullptr, G_PRIORITY_DEFAULT,
                             set_pending_activation_token,
                             g_strdup(activation_token), g_free);

  g_autoptr(GDBusMessage) reply = g_dbus_message_new_method_reply(message);
  g_dbus_connection_send_message(
      connection, reply, G_DBUS_SEND_MESSAGE_FLAGS_NONE, nullptr, nullptr);
  g_object_unref(message);
  return nullptr;
}

void _on_activate(GtkMenuItem* item, gpointer user_data) {
  gint id = GPOINTER_TO_INT(user_data);
  guint32 activation_timestamp = get_activation_timestamp();

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "id", fl_value_new_int(id));
  if (activation_timestamp != GDK_CURRENT_TIME) {
    fl_value_set_string_take(
        result_data, "activationTimestamp",
        fl_value_new_int(static_cast<gint64>(activation_timestamp)));
  }
  if (plugin_instance->pending_activation_token != nullptr) {
    fl_value_set_string_take(
        result_data, "activationToken",
        fl_value_new_string(plugin_instance->pending_activation_token));
    g_clear_pointer(&plugin_instance->pending_activation_token, g_free);
  }
  fl_method_channel_invoke_method(plugin_instance->channel,
                                  "onTrayMenuItemClick", result_data, nullptr,
                                  nullptr, nullptr);
}

GtkWidget* _create_menu(FlValue* args) {
  FlValue* items_value = fl_value_lookup_string(args, "items");

  GtkWidget* menu = gtk_menu_new();
  for (gint i = 0; i < fl_value_get_length(items_value); i++) {
    FlValue* item_value = fl_value_get_list_value(items_value, i);
    const int id = fl_value_get_int(fl_value_lookup_string(item_value, "id"));
    const char* type =
        fl_value_get_string(fl_value_lookup_string(item_value, "type"));
    const char* label =
        fl_value_get_string(fl_value_lookup_string(item_value, "label"));
    const bool disabled =
        fl_value_get_bool(fl_value_lookup_string(item_value, "disabled"));

    gint item_id = id;

    if (strcmp(type, "separator") == 0) {
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                            gtk_separator_menu_item_new());
    } else {
      GtkWidget* item = gtk_menu_item_new_with_label(label);

      if (disabled) {
        gtk_widget_set_sensitive(item, FALSE);
      }

      if (strcmp(type, "checkbox") == 0) {
        item = gtk_check_menu_item_new_with_label(label);
        const auto checked_value =
            fl_value_lookup_string(item_value, "checked");
        if (checked_value != nullptr) {
          const auto checked = fl_value_get_bool(checked_value);
          gtk_check_menu_item_set_active((GtkCheckMenuItem*)item, checked);
        }
      } else if (strcmp(type, "submenu") == 0) {
        GtkWidget* sub_menu =
            _create_menu(fl_value_lookup_string(item_value, "submenu"));
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(item), sub_menu);
      }

      g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_on_activate),
                       GINT_TO_POINTER(item_id));

      gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    }
  }
  return menu;
}

static FlMethodResponse* destroy(TrayManagerPlugin* self, FlValue* args) {
  if (!(!indicator)) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_PASSIVE);
  }
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_icon(TrayManagerPlugin* self, FlValue* args) {
  const char* id = fl_value_get_string(fl_value_lookup_string(args, "id"));
  const char* icon_path =
      fl_value_get_string(fl_value_lookup_string(args, "iconPath"));

  if (!menu)
    menu = gtk_menu_new();

  if (!indicator) {
    indicator = app_indicator_new(id, icon_path,
                                  APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

    app_indicator_set_menu(indicator, GTK_MENU(menu));
    gtk_widget_show_all(menu);
  }

  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_icon_full(indicator, icon_path, "");

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_title(TrayManagerPlugin* self, FlValue* args) {
  const char* title =
      fl_value_get_string(fl_value_lookup_string(args, "title"));

  app_indicator_set_label(indicator, title, NULL);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_context_menu(TrayManagerPlugin* self,
                                          FlValue* args) {
  menu = _create_menu(fl_value_lookup_string(args, "menu"));

  app_indicator_set_menu(indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void tray_manager_plugin_handle_method_call(TrayManagerPlugin* self,
                                                   FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "destroy") == 0) {
    response = destroy(self, args);
  } else if (strcmp(method, "setIcon") == 0) {
    response = set_icon(self, args);
  } else if (strcmp(method, "setTitle") == 0) {
    response = set_title(self, args);
  } else if (strcmp(method, "setContextMenu") == 0) {
    response = set_context_menu(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void tray_manager_plugin_dispose(GObject* object) {
  TrayManagerPlugin* self = TRAY_MANAGER_PLUGIN(object);
  if (self->session_bus != nullptr && self->session_bus_filter_id != 0) {
    g_dbus_connection_remove_filter(self->session_bus,
                                    self->session_bus_filter_id);
    self->session_bus_filter_id = 0;
  }
  g_clear_object(&self->session_bus);
  g_clear_pointer(&self->pending_activation_token, g_free);
  if (plugin_instance == self) {
    plugin_instance = nullptr;
  }
  G_OBJECT_CLASS(tray_manager_plugin_parent_class)->dispose(object);
}

static void tray_manager_plugin_class_init(TrayManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = tray_manager_plugin_dispose;
}

static void tray_manager_plugin_init(TrayManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(user_data);
  tray_manager_plugin_handle_method_call(plugin, method_call);
}

void tray_manager_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(
      g_object_new(tray_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "tray_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_autoptr(GError) error = nullptr;
  plugin->session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (plugin->session_bus != nullptr) {
    plugin->session_bus_filter_id = g_dbus_connection_add_filter(
        plugin->session_bus, session_bus_filter, nullptr, nullptr);
  } else {
    g_warning("Failed to connect to the session bus: %s",
              error == nullptr ? "unknown error" : error->message);
  }

  plugin_instance = plugin;

  g_object_unref(plugin);
}
