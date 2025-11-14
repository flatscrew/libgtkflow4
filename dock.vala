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
    /**
     * A widget that displays a {@link GFlow.Dock}
     *
     * Users may draw connections from and to this widget.
     * These widgets are only to be used inside implementations
     * of {@link GtkFlow.Node}
     */
    public class Dock : Gtk.Widget {
        public signal void connection_missed(double x, double y);
        
        public GFlow.Dock d { get; protected set; }
        private Gtk.GestureClick ctr_click;

        internal Value? last_value = null;

        /**
         * Creates a new Dock
         *
         * Requires the programmer to pass a {@link GFlow.Dock} to
         * the d-parameter.
         */
        public Dock(GFlow.Dock d, Gtk.Align label_alignment=Gtk.Align.FILL) {
            this.d = d;
            this.d.unlinked.connect(()=>{this.queue_draw();});
            this.d.linked.connect(()=>{this.queue_draw();});
            this.d.changed.connect(this.cb_changed);

            this.valign = Gtk.Align.CENTER;
            this.halign = Gtk.Align.CENTER;
            this.margin_start = 8;
            this.margin_end = 8;
            this.margin_top = 4;
            this.margin_bottom = 4;

            this.ctr_click = new Gtk.GestureClick();
            this.add_controller(this.ctr_click);
            this.ctr_click.pressed.connect((n, x, y) => { this.press_button(n,x,y); });
            
            this.add_css_class("gtkflow_dock");
        }

        private GtkFlow.NodeView? get_nodeview() {
            var parent = this.get_parent();
            while (true) {
                if (parent == null) {
                    return null;
                } else if (parent is NodeView) {
                    return (NodeView)parent;
                } else {
                    parent = parent.get_parent();
                }
            }
        }

        private void cb_changed(Value? value = null, string? flow_id = null) {
            var nv = this.get_nodeview();
            if (nv == null) {
                warning("Could not react to dock change: no nodeview");
                return;
            }
            if (value != null) {
                this.last_value = GLib.Value(value.type());
                value.copy(ref this.last_value);
            } else {
                this.last_value = null;
            }
            nv.queue_draw();
            this.queue_draw();
        }

        /**
         * Request for the color of this dock
         *
         * Use {@link GLib.Signal.connect_after} to override this
         * method and let your application decide what color to use
         * for connections that are going off this node.
         * Be aware that only {@link GFlow.Source}s dictate the colors of the
         * connections. If this Dock holds a {@link GFlow.Sink} it
         * will have no visible effect.
         */
        public signal Gdk.RGBA resolve_color(Dock d, Value? v) {
            return {0.0f,0.0f,0.0f,1.0f};
        }

        protected override void snapshot (Gtk.Snapshot sn) {
            int width = this.get_allocated_width();
            int height = this.get_allocated_height();
            
            if (width == 0 || height == 0) {
                warning("Dock snapshot skipped (0 size)");
                return;
            }
            
            var rect = Graphene.Rect().init(0, 0, width, height);
            var ctx = this.get_style_context();
            var cr = sn.append_cairo(rect);
        
            ctx.render_background(cr, 0, 0, width, height);
            ctx.render_frame(cr, 0, 0, width, height);
        
            if (!this.d.is_linked())
                return;
        
                
            Gdk.RGBA dot_color = {0.0f, 0.0f, 0.0f, 1.0f};
        
            if (this.d is GFlow.Source) {
                dot_color = this.resolve_color(this, this.last_value);
            } else if (this.d is GFlow.Sink && this.d.is_linked()) {
                var nv = this.get_nodeview();
                if (nv != null) {
                    var sink = (GFlow.Sink)this.d;
                    var sourcedock = nv.retrieve_dock(sink.sources.nth_data(0));
                    if (sourcedock != null)
                        dot_color = sourcedock.resolve_color(this, this.last_value);
                }
            }
        
            cr.save();
            cr.set_source_rgba(dot_color.red, dot_color.green, dot_color.blue, dot_color.alpha);
            cr.arc(width / 2.0, height / 2.0, 4.0, 0.0, 2 * Math.PI);
            cr.fill();
            cr.restore();
        }

        private void press_button(int n_clicked, double x, double y) {
            var picked = this.pick(x, y, Gtk.PickFlags.DEFAULT);
            if (picked == null) {
                return;
            }
            
            var nv = this.get_nodeview();
            if (nv == null) {
                warning("Dock could not process button press: no nodeview");
                return;
            }
            nv.start_temp_connector(this);
            nv.queue_allocate();
        }

        protected override void measure(Gtk.Orientation o, int for_size, out int min, out int pref, out int min_base, out int pref_base) {
            min = 16;
            pref = 16;
            min_base = -1;
            pref_base = -1;
        }
        
        public void notify_connection_miss(double x, double y) {
            this.connection_missed(x, y);
        }
    }
}
