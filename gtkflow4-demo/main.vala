class CustomDockLabelFactory : GtkFlow.NodeDockLabelWidgetFactory {

    private Gtk.SpinButton button;
    private GFlow.Node? node;

    public CustomDockLabelFactory(GFlow.Node node) {
        base(node);
    }

    public override Gtk.Widget create_dock_label(GFlow.Dock dock) {
        this.node = dock.node;
        var test_node = dock.node as TestNode;
        if (dock == test_node.source1) {
            this.button = new Gtk.SpinButton.with_range(0.0,1.0,0.01);
            button.halign = Gtk.Align.END;
            button.changed.connect (this.changed);
            return button;
        }
        return base.create_dock_label (dock);
    }

    private void changed() {
    }
}
class CustomNode : GtkFlow.Node {

    public CustomNode(TestNode node) {
        base.with_margin (node, 50, new CustomDockLabelFactory(node));
        set_title (custom_title_factory(this));

        var CSS = ".gtkflow_node { background: linear-gradient(0deg, rgba(150,111,136,1) 0%, rgba(175,175,222,1) 35%, rgba(0,212,255,1) 100%); }";
        Gtk.CssProvider custom_css = new Gtk.CssProvider();
        custom_css.load_from_data(CSS.data);
        get_style_context().add_provider(custom_css,Gtk.STYLE_PROVIDER_PRIORITY_USER);


        this.position_changed.connect(this.debug_position_changed);
        this.size_changed.connect(this.debug_size_changed);
     
    }

    private void debug_position_changed(int old_x, int old_y, int new_x, int new_y) {
        message("Position changed, old x = %d, old y = %d, new x = %d, new y %d\n", old_x, old_y, new_x, new_y);
    }

    private void debug_size_changed(int old_width, int old_height, int new_width, int new_height) {
        message("Size changed, old width = %d, old height = %d, new width = %d, new height %d\n", old_width, old_height, new_width, new_height);
    }

    private Gtk.Widget custom_title_factory (GtkFlow.Node node) {
        var custom_header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 3);
    
        var title_label = new Gtk.Label("");
        title_label.set_markup ("<b>%s</b>".printf(node.n.name));
        title_label.hexpand = true;
        title_label.halign = Gtk.Align.START;
        custom_header.append(title_label);
    
        var buttons_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    
        var delete_button = new Gtk.Button();
        delete_button.set_label ("Delete");
        delete_button.clicked.connect(node.remove);
        buttons_box.append(delete_button);
    
        var consumer_select = new Gtk.DropDown.from_strings ({"abc"});
        buttons_box.append (consumer_select);
    
        custom_header.append(buttons_box);
    
        return custom_header;
    }
}

class TestNode : GFlow.SimpleNode {
    public GFlow.SimpleSource source1;
    public GFlow.SimpleSource source2;
    public GFlow.SimpleSink sink1;

    public TestNode(string name) {
        this.name = name;

        try {
            this.source1 = new GFlow.SimpleSource (123);
            source1.unlinked.connect(() => message("Unlinked source1"));
            this.source1.name = "%s source 1".printf(name);
            this.add_source(source1);

            this.source2 = new GFlow.SimpleSource.with_type(typeof(int));
            source2.unlinked.connect(() => message("Unlinked source2"));
            this.source2.name = "%s source 2".printf(name);
            this.add_source(source2);

            this.sink1 = new GFlow.SimpleSink.with_type (typeof(int));
            sink1.unlinked.connect(() => message("Unlinked sink1"));
            
            this.sink1.name = "%s sink 1".printf(name);
            this.add_sink(sink1);
            this.sink1.max_sources = 10;
        } catch (GFlow.NodeError e) {
            warning("Couldn't build node");
        }
    }

    public void register_colors(GtkFlow.NodeView nv) {
        var src_widget1 = nv.retrieve_dock(this.source1);
        var src_widget2 = nv.retrieve_dock(this.source2);
        var snk_widget1 = nv.retrieve_dock(this.sink1);
        src_widget1.resolve_color.connect_after((d,v)=>{ return {1.0f,0.0f,0.0f,1.0f};});
        src_widget2.resolve_color.connect_after((d,v)=>{ return {0.0f,1.0f,0.0f,1.0f};});
        snk_widget1.resolve_color.connect_after((d,v)=>{ return {0.0f,0.0f,1.0f,1.0f};});
    }
}

int main (string[] args) {
  var app = new Gtk.Application(
    "de.grindhold.GtkFlow4Example",
    ApplicationFlags.FLAGS_NONE
  );

  app.activate.connect(() => {
    GtkFlow.init();
    
    var win = new Gtk.ApplicationWindow(app);
    win.set_default_size (800, 600);

    var btn = new Gtk.Button.with_label("Spawn Node");
    var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    var sw = new Gtk.ScrolledWindow();

    var nv = new GtkFlow.NodeView();
    var mm = new GtkFlow.Minimap();
    sw.child=nv;
    sw.vexpand=true;

    mm.nodeview = nv;

    btn.clicked.connect(()=>{
        var node = new TestNode("TestNode");
        var nn = new CustomNode (node);
        nv.add(nn);
    });

    var n1 = new TestNode("foo");
    var gn1 = new GtkFlow.Node(n1);
    var n2 = new TestNode("bar");

    var switch_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
    var switch_widget = new Gtk.Switch();
    switch_widget.vexpand = false;
    switch_box.append(new Gtk.Label("Switch:"));
    switch_box.append(switch_widget);
    
    gn1.add_child(new Gtk.Button.with_label("Button!"));
    gn1.add_child(switch_box);
    gn1.highlight_color = {0.6f,1.0f,0.0f,0.3f};
    nv.add(gn1);
    n1.register_colors(nv);
    var node2 = new GtkFlow.Node(n2);
    nv.add(node2);
    n2.register_colors(nv);

    node2.set_position(200, 200);

    try {
        n1.source1.link(n2.sink1);
    } catch (Error e) {
        warning("Could not link nodes: %s", e.message);
    }

    win.child = box;
    box.append(btn);
    box.append(mm);
    box.append(sw);
    win.present();
  });
  return app.run(args);
}

