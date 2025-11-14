namespace GtkFlow {
    
    const string CSS = "
        .gtkflow_node { 
            background: rgba(0.6, 0.6, 0.6, 0.2); 
            border-radius: 5px; 
            border: 1px solid rgba(128, 128, 128, 0.8); 
            box-shadow: 2px 2px 3px 3px rgba(153, 153, 153, 0.5);
        }

        .gtkflow_node_marked  { 
            background: rgba(0, 51, 128, 0.8); 
            border-radius: 5px; 
            border: 1px solid rgba(0, 51, 128, 0.8); 
            box-shadow: 2px 2px 3px 3px rgba(0, 51, 153, 0.5);
        }
    
        .gtkflow_dock {
            color: rgba(80,80,80,0.35);
            background-color: rgba(255,255,255,1);
            border-radius: 8px;
            border-width: 2px;
        }
          
        .gtkflow_dock:hover {
            background-color: #4a90e2;
        }
        ";
    
    public static void init() {
        var css = new Gtk.CssProvider();
        css.load_from_string(CSS);
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
}