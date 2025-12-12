/********************************************************************
# Copyright 2014-2022 Daniel 'grindhold' Brendle
#
# This file is part of libgtkflow.
#
# libgtkflow is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later
# version.
#
# libgtkflow is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with libgtkflow.
# If not, see http://www.gnu.org/licenses/.
*********************************************************************/

namespace GtkFlow {
    private errordomain InternalError {
        DOCKS_NOT_SUITABLE
    }

    private class NodeViewLayoutManager : Gtk.LayoutManager {
        protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        protected override void measure(Gtk.Widget w, Gtk.Orientation o, int for_size, out int min, out int pref, out int min_base, out int pref_base) {
            int lower_bound = 0;
            int upper_bound = 0;
            var c = w.get_first_child();
            while (c != null) {
                var lc = (NodeViewLayoutChild)this.get_layout_child(c);
                switch (o) {
                    case Gtk.Orientation.HORIZONTAL:
                        if (lc.x < 0) {
                            lower_bound = int.min(lc.x, lower_bound);
                        } else {
                            upper_bound = int.max(lc.x + c.get_width(), upper_bound);
                        }
                        break;
                    case Gtk.Orientation.VERTICAL:
                        if (lc.y < 0) {
                            lower_bound = int.min(lc.y, lower_bound);
                        } else {
                            upper_bound = int.max(lc.y + c.get_height(), upper_bound);
                        }
                        break;
                }

                c = c.get_next_sibling();
            }
            min = upper_bound - lower_bound;
            pref = upper_bound - lower_bound;
            min_base = -1;
            pref_base = -1;
        }

        protected override void allocate(Gtk.Widget w, int height, int width, int baseline) {
            var c = w.get_first_child();
            while (c != null) {
                int cwidth, cheight, _;
                c.measure(Gtk.Orientation.HORIZONTAL, -1, out cwidth, out _, out _, out _);
                c.measure(Gtk.Orientation.VERTICAL, -1, out cheight, out _, out _, out _);
                var lc = (NodeViewLayoutChild)this.get_layout_child(c);
                c.queue_allocate();
                c.allocate_size({lc.x,lc.y, cwidth, cheight}, -1);
                c = c.get_next_sibling();
            }
        }
        public override Gtk.LayoutChild create_layout_child (Gtk.Widget widget, Gtk.Widget for_child)  {
            return new NodeViewLayoutChild(for_child, this);
        }
    }

    private class NodeViewLayoutChild : Gtk.LayoutChild {
        public int x = 0;
        public int y = 0;

        public NodeViewLayoutChild(Gtk.Widget w, Gtk.LayoutManager lm) {
            Object(child_widget: w, layout_manager: lm);
        }
    }

    /**
     * A widget that displays flowgraphs expressed through {@link GFlow} objects
     *
     * This allows you to add {@link GFlow.Node}s to it in order to display
     * A graph of these nodes and their connections.
     */
    public class NodeView : Gtk.Widget {
        construct {
            set_css_name("gtkflow_nodeview");
        }
        
        public signal void dock_connection_missed(Dock dock, double x, double y);

        /**
         * If this property is set to true, the nodeview will not perform
         * any check wheter newly created connections will result in cycles
         * in the graph. It's completely up to the application programmer
         * to make sure that the logic inside the nodes he uses avoids
         * endlessly backpropagated loops
         */
        public bool allow_recursion {get; set; default=false;}

        /**
         * The eventcontrollers to receive events
         */
        private Gtk.EventControllerMotion ctr_motion;
        private Gtk.GestureClick ctr_click;

        /**
         * The current extents of the temporary connector
         * if null, there is no temporary connector drawn at the moment
         */
        private Gdk.Rectangle? temp_connector = null;

        /**
         * The dock that the temporary connector will be attched to
         */
        private Dock? temp_connected_dock = null;
        /**
         * The dock that was clicked to invoke the temporary connector
         */
        private Dock? clicked_dock = null;
        /**
         * The node that is being moved right now via mouse drag.
         * The node that receives the button press event registers
         * itself with this property
         */
        internal NodeRenderer? move_node {get; set; default=null;}
        internal NodeRenderer? resize_node {get; set; default=null;}

        /**
         * A rectangle detailing the extents of a rubber marking
         */
        private Gdk.Rectangle? mark_rubberband = null;

        /**
         * Instantiate a new NodeView
         */
        public NodeView (){
            this.set_layout_manager(new NodeViewLayoutManager());
            this.set_size_request(100,100);

            this.ctr_motion = new Gtk.EventControllerMotion();
            this.add_controller(this.ctr_motion);
            this.ctr_motion.motion.connect(this.process_motion);

            this.ctr_click = new Gtk.GestureClick();
            this.add_controller(this.ctr_click);
            this.ctr_click.pressed.connect(this.start_marking);
            this.ctr_click.released.connect(this.end_temp_connector);
        }

        /**
         * {@inheritDoc}
         */
        public override void dispose() {
            var nodewidget = this.get_first_child();
            while (nodewidget != null) {
                var delnode = nodewidget;
                nodewidget = nodewidget.get_next_sibling();
                delnode.unparent();
            }
            base.dispose();
        }

        internal List<unowned NodeRenderer> get_marked_nodes() {
            var result = new List<unowned NodeRenderer>();
            var nodewidget = this.get_first_child();
            while (nodewidget != null) {
                var node = nodewidget as NodeRenderer;
                if (node.marked) {
                    result.append(node);
                }
                nodewidget = nodewidget.get_next_sibling();
            }
            return result;
        }

        private void process_motion(double x, double y) {
            if (this.move_node != null && this.layout_manager != null) {
                var lc = (NodeViewLayoutChild) this.layout_manager.get_layout_child(this.move_node);
                int old_x = lc.x;
                int old_y = lc.y;
                lc.x = (int)(x-this.move_node.click_offset_x);
                lc.y = (int)(y-this.move_node.click_offset_y);
                if (this.move_node.marked) {
                    foreach (NodeRenderer n in this.get_marked_nodes()) {
                        if (n == this.move_node) continue;
                        var mlc = (NodeViewLayoutChild) this.layout_manager.get_layout_child(n);
                        mlc.x -= old_x - lc.x;
                        mlc.y -= old_y - lc.y;
                    }
                }
            }

            if (this.resize_node != null) {
                int d_x, d_y;
                Gtk.Allocation node_alloc;
                this.resize_node.get_allocation(out node_alloc);
                d_x = (int)(x-this.resize_node.click_offset_x-node_alloc.x);
                d_y = (int)(y-this.resize_node.click_offset_y-node_alloc.y);
                int new_width = (int)this.resize_node.resize_start_width+d_x;
                int new_height = (int)this.resize_node.resize_start_height+d_y;
                this.resize_node.set_size_request(new_width, new_height);
            }

            if (this.temp_connector != null) {
                var n = (NodeRenderer)this.retrieve_node(this.temp_connected_dock.d.node);
                this.temp_connector.width = (int)(x - this.temp_connector.x-n.get_margin());
                this.temp_connector.height = (int)(y - this.temp_connector.y-n.get_margin());
            }

            if (this.mark_rubberband != null) {
                this.mark_rubberband.width = (int)(x - this.mark_rubberband.x);
                this.mark_rubberband.height = (int)(y - this.mark_rubberband.y);
                var nodewidget = this.get_first_child();
                Gtk.Allocation node_alloc;
                Gdk.Rectangle absolute_marked = this.mark_rubberband;
                if (absolute_marked.width < 0) {
                    absolute_marked.width *= -1;
                    absolute_marked.x -= absolute_marked.width;
                }
                if (absolute_marked.height < 0) {
                    absolute_marked.height *= -1;
                    absolute_marked.y -= absolute_marked.height;
                }
                Gdk.Rectangle result;
                while (nodewidget != null) {
                    var node = (NodeRenderer)nodewidget;
                    node.get_allocation(out node_alloc);
                    node_alloc.intersect(absolute_marked, out result);
                    node.marked = result == node_alloc;
                    nodewidget = node.get_next_sibling();
                }
            }
            this.queue_allocate();
        }

        private void start_marking(int n_clicks, double x, double y) {
            if (this.pick(x,y, Gtk.PickFlags.DEFAULT) == this)
                this.mark_rubberband = {(int)x,(int)y,0,0};
        }

        internal void start_temp_connector(Dock d) {
            this.clicked_dock = d;
            if (d.d is GFlow.Sink && d.d.is_linked()) {
                var sink = (GFlow.Sink)d.d;
                this.temp_connected_dock = this.retrieve_dock(sink.sources.last().nth_data(0));
            } else {
                this.temp_connected_dock = d;
            }
            var node = this.retrieve_node(this.temp_connected_dock.d.node);

            Gtk.Allocation node_alloc, dock_alloc;
            node.get_allocation(out node_alloc);
            this.temp_connected_dock.get_allocation(out dock_alloc);
            var x = node_alloc.x + dock_alloc.x + 8;
            var y = node_alloc.y + dock_alloc.y + 8;
            this.temp_connector = {x, y, 0, 0};
        }

        internal void end_temp_connector(int n_clicks, double x, double y) {
            var picked_widget = this.pick(x, y, Gtk.PickFlags.DEFAULT);
            
            if (this.temp_connector != null) {
                if (picked_widget is Dock) {
                    var pd = (Dock) picked_widget;
                    if (pd.d is GFlow.Source && this.temp_connected_dock.d is GFlow.Sink
                     || pd.d is GFlow.Sink && this.temp_connected_dock.d is GFlow.Source) {
                        try {
                            if (!this.is_suitable_target(pd.d, this.temp_connected_dock.d)) {
                                throw new InternalError.DOCKS_NOT_SUITABLE("Can't link because is no good");
                            }
                            pd.d.link(this.temp_connected_dock.d);
                        } catch (Error e) {
                            warning("Could not link: "+e.message);
                        }
                    }
                    else if (pd.d is GFlow.Sink && this.clicked_dock != null
                      && this.clicked_dock.d is GFlow.Sink
                      && this.temp_connected_dock is GFlow.Source) {
                        try {
                            if (!this.is_suitable_target(pd.d, this.temp_connected_dock.d)) {
                                throw new InternalError.DOCKS_NOT_SUITABLE("Can't link because is no good");
                            }
                            this.clicked_dock.d.unlink(this.temp_connected_dock.d);
                            pd.d.link(this.temp_connected_dock.d);
                        } catch (Error e) {
                            warning("Could not edit links: "+e.message);
                        }

                    }
                    pd.queue_draw();
                } else {
                    if (this.temp_connected_dock.d is GFlow.Source
                     && this.clicked_dock != null
                     && this.clicked_dock.d is GFlow.Sink) {
                        try {
                            this.clicked_dock.d.unlink(this.temp_connected_dock.d);
                        } catch (Error e) {
                            warning("Could not unlink: %s", e.message);
                        }
                     } else {
                        this.temp_connected_dock.notify_connection_miss(x, y);
                        missed_temp_connector(x, y);
                     }
                }

                this.queue_draw();
                this.temp_connected_dock.queue_draw();
                if (this.clicked_dock != null) {
                    this.clicked_dock.queue_draw();
                }
                this.clicked_dock = null;
                this.temp_connected_dock = null;
                this.temp_connector = null;
            } 

            this.update_extents();
            this.queue_resize();
            this.mark_rubberband = null;
            this.queue_allocate();
        }
        
        private void missed_temp_connector(double x, double y) {
            this.dock_connection_missed(this.temp_connected_dock, x, y);
        }

        private void update_extents() {
            int min_x=0, min_y = 0;
            NodeViewLayoutChild lc;
            var child = this.get_first_child();
            while (child != null) {
                lc = (NodeViewLayoutChild)this.layout_manager.get_layout_child(child);
                min_x = int.min(min_x, lc.x);
                min_y = int.min(min_y, lc.y);
                child = child.get_next_sibling();
            }
            if (min_x >= 0 && min_y >= 0) {
                return;
            }
            child = this.get_first_child();
            while (child != null) {
                lc = (NodeViewLayoutChild)this.layout_manager.get_layout_child(child);
                if (min_x < 0)
                lc.x += -min_x;
                if (min_y < 0)
                lc.y += -min_y;
                child = child.get_next_sibling();
            }
            var parent = this.get_parent();
            if (parent!=null && parent is Gtk.Viewport) {
                var scrollwidget = parent.get_parent();
                if (parent != null && parent is Gtk.ScrolledWindow) {
                    var sw = (Gtk.ScrolledWindow)scrollwidget;
                    sw.hadjustment.value += (double)(-min_x);
                    sw.vadjustment.value += (double)(-min_y);
                }
            }
        }

        public void bring_node_to_front(NodeRenderer node) {
            var last = this.get_last_child();
            if (last == node) return;

            node.insert_after(this, last);
        }

        /**
         * Add a node to this nodeview
         */
        public void add(NodeRenderer n) {
            n.set_parent (this);
        }

        /**
         * Remove a node from this nodeview
         */
        public void remove(NodeRenderer n) {
            n.n.unlink_all();
            var child = get_first_child ();
            while (child != null) {
                if (child == n) {
                    child.unparent ();
                    child = null;
                    return;
                }
                child = child.get_next_sibling();
            }
        }

        /**
         * Retrieve a Node-Widget from this node.
         *
         * Gives you the {@link GtkFlow.Node}-object that corresponds to the given
         * {@link GFlow.Node}. Returns null if the searched Node is not associated
         * with any of the Node-Widgets in this nodeview.
         */
        public NodeRenderer? retrieve_node (GFlow.Node n) {
            var c = (NodeRenderer)this.get_first_child();
            while (c != null) {
                if (!(c is NodeRenderer )) continue;
                if (c.n == n) return c;
                c = (NodeRenderer)c.get_next_sibling();
            }
            return null;
        }

        /**
         * Retrieve a Dock-Widget from this nodeview.
         *
         * Gives you a {@link Dock}-object that corresponds to the given
         * {@link GFlow.Dock}. Returns null if the given Dock is not 
         * associated with any of the Dock-Widgets in this nodeview.
         */
        public Dock? retrieve_dock (GFlow.Dock d) {
            var c = (NodeRenderer)this.get_first_child();
            Dock? found = null;
            while (c != null) {
                if (!(c is NodeRenderer )) {
                    c = (NodeRenderer)c.get_next_sibling();
                    continue;
                }
                found = c.retrieve_dock(d);
                if (found != null) return found;
                c = (NodeRenderer)c.get_next_sibling();
            }
            return null;
        }

        /**
         * Determines wheter one dock can be dropped on another
         */
        private bool is_suitable_target (GFlow.Dock from, GFlow.Dock to) {
            // Check whether the docks have the same type
            if (!from.has_same_type(to))
                return false;
            // Check if the target would lead to a recursion
            // If yes, return the value of allow_recursion. If this
            // value is set to true, it's completely fine to have
            // a recursive graph
            if (to is GFlow.Source && from is GFlow.Sink) {
                if (!this.allow_recursion)
                    if (from.node.is_recursive_forward(to.node) ||
                           to.node.is_recursive_backward(from.node))
                        return false;
            }
            if (to is GFlow.Sink && from is GFlow.Source) {
                if (!this.allow_recursion)
                    if (to.node.is_recursive_forward(from.node) ||
                           from.node.is_recursive_backward(to.node))
                        return false;
            }
            if (to is GFlow.Sink && from is GFlow.Sink) {
                GFlow.Source? s = ((GFlow.Sink)from).sources.last().nth_data(0);
                if (s == null)
                    return false;
                if (!this.allow_recursion)
                    if (to.node.is_recursive_forward(s.node) ||
                           s.node.is_recursive_backward(to.node))
                        return false;
            }
            // If the from from-target is a sink, check if the
            // to target is either a source which does not belong to the own node
            // or if the to target is another sink (this is valid as we can
            // move a connection from one sink to another
            if (from is GFlow.Sink
                    && ((to is GFlow.Sink
                    && to != from)
                    || (to is GFlow.Source
                    && (!to.node.has_dock(from) || this.allow_recursion)))) {
                return true;
            }
            // Check if the from-target is a source. if yes, make sure the
            // to-target is a sink and it does not belong to the own node
            else if (from is GFlow.Source
                    && to is GFlow.Sink
                    && (!to.node.has_dock(from) || this.allow_recursion)) {
                return true;
            }
            return false;
        }

        internal signal void draw_minimap();

        protected override void snapshot (Gtk.Snapshot sn) {
            var rect = Graphene.Rect().init(0,0,(float)this.get_width(), (float)this.get_height());
            var cr = sn.append_cairo(rect);

            Gdk.RGBA color = {0.0f,0.0f,0.0f,1.0f};

            var c = this.get_first_child();
            while (c != null) {
                var nr = (NodeRenderer)c;
                int tgt_x, tgt_y, src_x, src_y, w, h;
                
                foreach (GFlow.Sink snk in nr.n.get_sinks()) {
                    var target_dock = this.retrieve_dock(snk);
                    Gtk.Allocation tgt_alloc, tgt_node_alloc;
                    target_dock.get_allocation(out tgt_alloc);
                    nr.get_allocation(out tgt_node_alloc);
                    
                    foreach (GFlow.Source src in snk.sources) {
                        if (this.temp_connected_dock != null && src == this.temp_connected_dock.d
                         && this.clicked_dock != null && snk == this.clicked_dock.d) {
                            continue;
                        }

                        var source_dock = this.retrieve_dock(src);
                        var source_node = this.retrieve_node(src.node);
                        
                        Gtk.Allocation src_dock_alloc, src_node_alloc;
                        source_dock.get_allocation(out src_dock_alloc);
                        source_node.get_allocation(out src_node_alloc);
                        src_x = src_dock_alloc.x+src_node_alloc.x+source_node.get_margin() + 8;
                        src_y = src_dock_alloc.y+src_node_alloc.y+source_node.get_margin() + 8;
                        
                        tgt_x = tgt_alloc.x+tgt_node_alloc.x+nr.get_margin() + 8;
                        tgt_y = tgt_alloc.y+tgt_node_alloc.y+nr.get_margin() + 8;
                        w = tgt_x - src_x;
                        h = tgt_y - src_y;

                        var sourcedock = this.retrieve_dock(src);
                        if (sourcedock != null) {
                            color = sourcedock.resolve_color(sourcedock, sourcedock.last_value);
                        }

                        cr.save();
                        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                        cr.move_to(src_x, src_y);
                        
                        if (w > 0) {
                            cr.rel_curve_to(w/3,0,2*w/3,h,w,h);
                        } else {
                            cr.rel_curve_to(-w/3,0,1.3*w,h,w,h);
                        }
                        
                        cr.stroke();
                        cr.restore();
                    }
                }
                c = c.get_next_sibling();
            }
            
            base.snapshot(sn);
            this.draw_minimap();
            
            var rect2 = Graphene.Rect().init(0,0,(float)this.get_width(), (float)this.get_height());
            var cr2 = sn.append_cairo(rect2);

            if (this.temp_connector != null) {
                color = this.temp_connected_dock.resolve_color(
                    this.temp_connected_dock, this.temp_connected_dock.last_value
                );
                var nr = this.retrieve_node(this.temp_connected_dock.d.node);

                cr2.save();
                cr2.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                cr2.move_to(this.temp_connector.x+nr.get_margin(),
                            this.temp_connector.y+nr.get_margin());
                cr2.rel_curve_to(
                    this.temp_connector.width/3,
                    0,
                    2*this.temp_connector.width/3,
                    this.temp_connector.height,
                    this.temp_connector.width,
                    this.temp_connector.height
                );
                cr2.stroke();
                cr2.restore();
            }

            if (this.mark_rubberband != null) {
                cr2.save();
                cr2.set_source_rgba(0.0, 0.2, 0.9, 0.4);
                cr2.rectangle(
                    this.mark_rubberband.x, this.mark_rubberband.y,
                    this.mark_rubberband.width, this.mark_rubberband.height
                );
                cr2.fill();
                cr2.set_source_rgba(0.0, 0.2, 1.0, 1.0);
                cr2.stroke();
                cr2.restore();
            }
        }
    }
}

