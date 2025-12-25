package notify

type Notifier interface {
	Notify(title, text string) error
}
